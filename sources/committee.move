// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[allow(unused_use)]
module bridge::committee {
    use sui::hash;
    use sui::ecdsa_k1;
    use sui::event::emit;
    use sui::vec_map::{Self, VecMap};
    use sui::vec_set;
    // use sui_system::sui_system::SuiSystemState;

    use bridge::crypto;
    use bridge::message::{Self, Blocklist, BridgeMessage};

    const ESignatureBelowThreshold: u64 = 0;
    const EDuplicatedSignature: u64 = 1;
    const EInvalidSignature: u64 = 2;
    const EBlocklistedSignature: u64 = 3;
    // const ENotSystemAddress: u64 = 3;
    const ECommitteeBlocklistContainsUnknownKey: u64 = 4;
    // const ESenderNotActiveCommittee: u64 = 5;
    const EInvalidPubkeyLength: u64 = 6;
    // const ECommitteeAlreadyInitiated: u64 = 7;
    // const EDuplicatePubkey: u64 = 8;
    // const ESenderIsNotInBridgeCommittee: u64 = 9;

    // const SUI_MESSAGE_PREFIX: vector<u8> = b"SUI_BRIDGE_MESSAGE";

    const ECDSA_ADDRESS_LENGTH: u64 = 20;

    //////////////////////////////////////////////////////
    // Types
    //

    public struct BlocklistCommitteeEvent has copy, drop {
        blocklisted: bool,
        public_keys: vector<vector<u8>>,
    }

    public struct BridgeCommittee has store {
        // commitee address and weight
        members: VecMap<vector<u8>, CommitteeMember>,
        // Committee member registrations for the next committee creation.
        member_registrations: vector<vector<u8>>,
        // Epoch when the current committee was updated,
        // the voting power for each of the committee members are snapshot from this epoch.
        // This is mainly for verification/auditing purposes, it might not be useful for bridge operations.
        last_committee_update_epoch: u64,
    }

    public struct CommitteeUpdateEvent has copy, drop {
        // commitee address and weight
        members: VecMap<vector<u8>, CommitteeMember>,
        stake_participation_percentage: u64
    }

    // public struct CommitteeMemberUrlUpdateEvent has copy, drop {
    //     member: vector<u8>,
    //     new_url: vector<u8>,
    // }

    public struct CommitteeMember has copy, drop, store {
        // The Sui Address of the committee; delete
        // sui_address: address,
        /// The public key bytes of the bridge key
        bridge_pubkey_bytes: vector<u8>,
        /// Voting power, values are voting power in the scale of 10000.
        voting_power: u64,
        // The HTTP REST URL the member's node listens to
        // it looks like b'https://127.0.0.1:9191'
        // http_rest_url: vector<u8>,
        /// If this member is blocklisted
        blocklisted: bool,
    }

    // public struct CommitteeMemberRegistration has copy, drop, store {
    //     /// The Sui Address of the committee
    //     sui_address: address,
    //     /// The public key bytes of the bridge key
    //     bridge_pubkey_bytes: vector<u8>,
    //     // The HTTP REST URL the member's node listens to
    //     // it looks like b'https://127.0.0.1:9191'
    //     // http_rest_url: vector<u8>,
    // }


    public struct CommitteeMemberRegistrationUpdateEvent has copy, drop {
        /// The committee member registrations; eth public key
        registrations: VecMap<vector<u8>, bool>,
    }

    //////////////////////////////////////////////////////
    // Public functions
    //
    
    /// Recover the Ethereum address using the signature and message, assuming the signature was
    /// produced over the Keccak256 hash of the message. Output an object with the recovered address
    /// to recipient.
    public fun recover_signer(
        msg: BridgeMessage,
        mut signature: vector<u8>,
    ): vector<u8> {
        // Normalize the last byte of the signature to be 0 or 1.
        let v = &mut signature[64];
        if (*v == 27) {
            *v = 0;
        } else if (*v == 28) {
            *v = 1;
        } else if (*v > 35) {
            *v = (*v - 1) % 2;
        };

        // Ethereum signature is produced with Keccak256 hash of the message, so the last param is
        // 0.
        let pubkey = ecdsa_k1::secp256k1_ecrecover(&signature, &msg.serialize_message(), 0);
        pubkey_to_address(pubkey)
    }

    public fun pubkey_to_address(eth_pubkey: vector<u8>):(vector<u8>) {
        let uncompressed = ecdsa_k1::decompress_pubkey(&eth_pubkey);

        // Take the last 64 bytes of the uncompressed pubkey.
        let mut uncompressed_64 = vector[];
        let mut i = 1;
        while (i < 65) {
            uncompressed_64.push_back(uncompressed[i]);
            i = i + 1;
        };

        // Take the last 20 bytes of the hash of the 64-bytes uncompressed pubkey.
        let hashed = sui::hash::keccak256(&uncompressed_64);
        let mut addr = vector[];
        let mut i = 12;
        while (i < 32) {
            addr.push_back(hashed[i]);
            i = i + 1;
        };
        addr    
    }

    public fun verify_signatures(
        self: &BridgeCommittee,
        message: BridgeMessage,
        signatures: vector<vector<u8>>,
    ) {
        let (mut i, signature_counts) = (0, vector::length(&signatures));
        let mut seen_pub_key = vec_set::empty<vector<u8>>();
        let required_voting_power = message.required_voting_power();
        // add prefix to the message bytes
        // let mut message_bytes = SUI_MESSAGE_PREFIX;
        // message_bytes.append(message.serialize_message());

        let mut threshold = 0;
        while (i < signature_counts) {
            let pubkey = recover_signer(message,signatures[i]);
            // check duplicate
            // and make sure pub key is part of the committee
            assert!(!seen_pub_key.contains(&pubkey), EDuplicatedSignature);
            assert!(self.members.contains(&pubkey), EInvalidSignature);

            // get committee signature weight and check pubkey is part of the committee
            let member = &self.members[&pubkey];
            assert!(!member.blocklisted, EBlocklistedSignature);
            
            threshold = threshold + member.voting_power;
            seen_pub_key.insert(pubkey);
            i = i + 1;
        };
        
        assert!(threshold >= required_voting_power, ESignatureBelowThreshold);
    }

    //////////////////////////////////////////////////////
    // Internal functions
    //

    public(package) fun create(): BridgeCommittee {
        // assert!(tx_context::sender(ctx) == @0x0, ENotSystemAddress);
        BridgeCommittee {
            members: vec_map::empty(),
            member_registrations: vector::empty(),
            last_committee_update_epoch: 0,
        }
    }

    public(package) fun register(
        self: &mut BridgeCommittee,
        bridge_member_address_vec: vector<vector<u8>>,
    ) {
        // We disallow registration after committee initiated in v1
        // assert!(self.members.is_empty(), ECommitteeAlreadyInitiated);
        
        let mut i = 0;
        let mut new_registrations = vec_map::empty();
        let len = bridge_member_address_vec.length();
    
        while (i < len) {
            let bridge_member_address = bridge_member_address_vec.borrow(i);
            
            assert!(bridge_member_address.length() == ECDSA_ADDRESS_LENGTH, EInvalidPubkeyLength);
          
            if (!self.member_registrations.contains(bridge_member_address)) {
                new_registrations.insert(*bridge_member_address, true);
                let _bridge_member_address = *bridge_member_address;
                // check_uniqueness_bridge_keys(self, _bridge_member_address);
                self.member_registrations.push_back( _bridge_member_address);
            };

            // In case committee need to update the info

            // check uniqueness of the bridge pubkey.
            // `try_create_next_committee` will abort if bridge_pubkey_bytes are not unique and
            // that will fail the end of epoch transaction (possibly "forever", well, we
            // need to deploy proper committee changes to stop end of epoch from failing).
            i = i + 1;
        };


        emit(CommitteeMemberRegistrationUpdateEvent{registrations: new_registrations})
    }

    // This method will try to create the next committee using the registration and system state,
    // if the total stake fails to meet the minimum required percentage, it will skip the update.
    // This is to ensure we don't fail the end of epoch transaction.
    public(package) fun try_create_next_committee(
        self: &mut BridgeCommittee,
        active_committee_powers: VecMap<vector<u8>, u64>,
        min_stake_participation_percentage: u64,
        ctx: &TxContext
    ) {
        let mut i = 0;
        let mut new_members = vec_map::empty();
        let mut stake_participation_percentage = 0;

        while (i < self.member_registrations.length()) {
            // retrieve registration
            let bridge_pubkey_bytes = self.member_registrations.borrow(i);
            // Find committee stake amount from system state

            // Process registration if it's active committee
            let voting_power = active_committee_powers.try_get(bridge_pubkey_bytes);
            if (voting_power.is_some()) {
                let voting_power = voting_power.destroy_some();
                stake_participation_percentage = stake_participation_percentage + voting_power;

                let member = CommitteeMember {
                    bridge_pubkey_bytes: *bridge_pubkey_bytes,
                    voting_power: (voting_power as u64),
                    // http_rest_url: registration.http_rest_url,
                    blocklisted: false,
                };

                new_members.insert(*bridge_pubkey_bytes, member)
            };

            i = i + 1;
        };

        // Make sure the new committee represent enough stakes, percentage are accurate to 2DP
        if (stake_participation_percentage >= min_stake_participation_percentage) {
            // Clear registrations
            self.member_registrations = vector::empty();
            // Store new committee info
            self.members = new_members;
            self.last_committee_update_epoch = ctx.epoch();

            emit(CommitteeUpdateEvent {
                members: new_members,
                stake_participation_percentage
            })
        }
    }

    // This function applys the blocklist to the committee members, we won't need to run this very often so this is not gas optimised.
    // TODO: add tests for this function
    public(package) fun execute_blocklist(self: &mut BridgeCommittee, blocklist: Blocklist) {
        let blocklisted = blocklist.blocklist_type() != 1;
        let eth_addresses = blocklist.blocklist_committee_addresses();
        let list_len = eth_addresses.length();
        let mut list_idx = 0;
        let mut member_idx = 0;
        let mut pub_keys = vector[];

        while (list_idx < list_len) {
            let target_address = &eth_addresses[list_idx];
            let mut found = false;

            while (member_idx < self.members.size()) {
                let (eth_address, member) = self.members.get_entry_by_idx_mut(member_idx);

                if (*target_address == *eth_address) {
                    member.blocklisted = blocklisted;
                    pub_keys.push_back(*eth_address);
                    found = true;
                    member_idx = 0;
                    break
                };

                member_idx = member_idx + 1;
            };

            assert!(found, ECommitteeBlocklistContainsUnknownKey);
            list_idx = list_idx + 1;
        };

        emit(BlocklistCommitteeEvent {
            blocklisted,
            public_keys: pub_keys,
        })
    }

    public(package) fun committee_members(
        self: &BridgeCommittee,
    ): &VecMap<vector<u8>, CommitteeMember> {
        &self.members
    }

    // public(package) fun update_node_url(self: &mut BridgeCommittee, new_url: vector<u8>, ctx: &TxContext) {
    //     let mut idx = 0;
    //     while (idx < self.members.size()) {
    //         let (_, member) = self.members.get_entry_by_idx_mut(idx);
    //         if (member.sui_address == ctx.sender()) {
    //             member.http_rest_url = new_url;
    //             emit (CommitteeMemberUrlUpdateEvent {
    //                 member: member.bridge_pubkey_bytes,
    //                 new_url
    //             });
    //             return
    //         };
    //         idx = idx + 1;
    //     };
    //     abort ESenderIsNotInBridgeCommittee
    // }

    // Assert if `bridge_pubkey_bytes` is duplicated in `member_registrations`.
    // Dupicate keys would cause `try_create_next_committee` to fail and,
    // in consequence, an end of epoch transaction to fail (safe mode run).
    // This check will ensure the creation of the committee is correct.
    // fun check_uniqueness_bridge_keys(self: &BridgeCommittee, _bridge_pubkey_bytes: vector<u8>) {
    //     let mut count = self.member_registrations.length();
    //     // bridge_pubkey_bytes must be found once and once only
    //     let mut bridge_key_found = false;
    //     while (count > 0) {
    //         count = count - 1;
    //         let bridge_pubkey_bytes = self.member_registrations.borrow(count);
    //         if (bridge_pubkey_bytes == _bridge_pubkey_bytes) {
    //             assert!(!bridge_key_found, EDuplicatePubkey);
    //             bridge_key_found = true; // bridge_pubkey_bytes found, we must not have another one
    //         }
    //     };
    // }

    //////////////////////////////////////////////////////
    // Test functions
    //

    #[test_only]
    public(package) fun members(self: &BridgeCommittee): &VecMap<vector<u8>, CommitteeMember> {
        &self.members
    }

    #[test_only]
    public(package) fun voting_power(member: &CommitteeMember): u64 {
        member.voting_power
    }

    // #[test_only]
    // public(package) fun http_rest_url(member: &CommitteeMember): vector<u8> {
    //     member.http_rest_url
    // }

    #[test_only]
    public(package) fun member_registrations(
        self: &BridgeCommittee,
    ): &vector<vector<u8>> {
        &self.member_registrations
    }

    #[test_only]
    public(package) fun blocklisted(member: &CommitteeMember): bool {
        member.blocklisted
    }

    // #[test_only]
    // public(package) fun bridge_pubkey_bytes(registration: &CommitteeMemberRegistration): &vector<u8> {
    //     &registration.bridge_pubkey_bytes
    // }

    #[test_only]
    public(package) fun make_bridge_committee(
        members: VecMap<vector<u8>, CommitteeMember>,
        member_registrations: vector<vector<u8>>,
        last_committee_update_epoch: u64,
    ): BridgeCommittee {
        BridgeCommittee {
            members,
            member_registrations,
            last_committee_update_epoch,
        }
    }

    #[test_only]
    public(package) fun make_committee_member(
        // sui_address: address,
        bridge_pubkey_bytes: vector<u8>,
        voting_power: u64,
        // http_rest_url: vector<u8>,
        blocklisted: bool,
    ): CommitteeMember {
        CommitteeMember {
            // sui_address,
            bridge_pubkey_bytes,
            voting_power,
            // http_rest_url,
            blocklisted,
        }
    }
}
