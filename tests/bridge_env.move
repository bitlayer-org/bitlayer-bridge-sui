// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module bridge::bridge_env {
    use sui::vec_map;
    use bridge::bridge::{
        test_init_bridge_committee,
        AdminCap,
        Bridge,
        update_submitter,
        assert_not_paused,
        assert_paused,
        // create_bridge_for_testing,
        inner_token_transfer_records,
        test_load_inner_mut,
        EmergencyOpEvent,
        TokenWithdrawEvent,
        TokenTransferAlreadyApproved,
        TokenTransferAlreadyClaimed,
        TokenTransferApproved,
        TokenTransferClaimed,
        TokenTransferLimitExceed
    };
    use bridge::sbtc::{Self, init_test, SBTC};
    use bridge::chain_ids;
    use bridge::committee::{Self,BlocklistCommitteeEvent};
    use bridge::message::{
        Self,
        BridgeMessage,
        create_add_tokens_on_sui_message,
        create_add_routes_on_sui_message,
        create_blocklist_message,
        emergency_op_pause,
        emergency_op_unpause
    };
    use bridge::treasury::{
        TokenRegistrationEvent,
        NewTokenEvent,
        UpdateTokenPriceEvent
    };
    use bridge::message_types;
    use std::type_name;
    use std::ascii::String;
    use sui::clock::Clock;
    use sui::event;
    use sui::coin::{ Coin, CoinMetadata, TreasuryCap};
    use sui::ecdsa_k1::{KeyPair, secp256k1_keypair_from_seed, secp256k1_sign};
    use sui::test_scenario::{Self, Scenario};
    use sui::test_utils::destroy;
    use sui::test_utils::create_one_time_witness;

    use bridge::limiter::UpdateRouteLimitEvent;
    
    use bridge::test_token::{Self, TEST_TOKEN};
    use sui::address;

    //
    // Chain IDs
    //
    const SOURCE_CHAIN_ID: u8 = 4;

    //
    // Token IDs
    //
    const BTC_ID: u8 = 5;

    //
    // Claim status
    //
    const CLAIMED: u8 = 1;
    const ALREADY_CLAIMED: u8 = 2;
    const LIMIT_EXCEEDED: u8 = 3;

    public fun claimed(): u8 {
        CLAIMED
    }

    public fun already_claimed(): u8 {
        ALREADY_CLAIMED
    }

    public fun limit_exceeded(): u8 {
        LIMIT_EXCEEDED
    }

    //
    // Approve status
    //
    const APPROVED: u8 = 1;
    const ALREADY_APPROVED: u8 = 2;

    public fun approved(): u8 {
        APPROVED
    }

    public fun already_approved(): u8 {
        ALREADY_APPROVED
    }

    //
    // Test addresses
    //
    const SUBMITTER: address = @0xa;

    public fun test_source_chain_id(): u8 {
        SOURCE_CHAIN_ID
    }

    public fun test_btc_id(): u8 {
        BTC_ID
    }

    //
    // Bridge Committee setup and info
    //

    // Bridge Committee info
    public struct BridgeCommittee has drop {
        key_pair: KeyPair,
        stake_amount: u64,
    }

    public fun create_committee(
        stake_amount: u64,
        seed: &vector<u8>,
    ): BridgeCommittee {
        BridgeCommittee {
            key_pair: secp256k1_keypair_from_seed(seed),
            stake_amount,
        }
    }

    // Bridge environemnt
    public struct BridgeEnv {
        scenario: Scenario,
        chain_id: u8,
        submitter: address,
        // vault: Vault,
        committees: vector<BridgeCommittee>,
        clock: Clock,
    }

    // Freeze the bridge
    public fun freeze_bridge(env: &mut BridgeEnv, sender: address, error: u64) {
        // set up
        let scenario = env.scenario();
        scenario.next_tx(sender);
        let mut bridge = scenario.take_shared<Bridge>();
        let seq_num = bridge.get_seq_num_for(message_types::emergency_op());

        // message signed
        let msg = message::create_emergency_op_message(
            env.chain_id,
            seq_num,
            emergency_op_pause(),
        );
        let signatures = env.sign_message(msg);

        // run freeze
        bridge.execute_system_message(msg, signatures);

        // verify freeze events
        let register_events = event::events_by_type<EmergencyOpEvent>();
        assert!(register_events.length() == 1);
        assert!(register_events[0].unwrap_emergency_op_event() == true);

        // verify freeze
        let inner = bridge.test_load_inner_mut();
        inner.assert_paused(error);

        // tear down
        test_scenario::return_shared(bridge);
    }

    // Unfreeze the bridge
    public fun unfreeze_bridge(
        env: &mut BridgeEnv,
        sender: address,
        error: u64,
    ) {
        // set up
        let scenario = env.scenario();
        scenario.next_tx(sender);
        let mut bridge = scenario.take_shared<Bridge>();
        let seq_num = bridge.get_seq_num_for(message_types::emergency_op());

        // message signed
        let msg = message::create_emergency_op_message(
            env.chain_id,
            seq_num,
            emergency_op_unpause(),
        );
        let signatures = env.sign_message(msg);

        // run unfreeze
        bridge.execute_system_message(msg, signatures);
        let register_events = event::events_by_type<EmergencyOpEvent>();
        assert!(register_events.length() == 1);
        assert!(register_events[0].unwrap_emergency_op_event() == false);

        // verify unfreeze events

        // verify unfreeze
        let inner = bridge.test_load_inner_mut();
        inner.assert_not_paused(error);

        // tear down
        test_scenario::return_shared(bridge);
    }

    //
    // Getters
    //

    public fun ctx(env: &mut BridgeEnv): &mut TxContext {
        env.scenario.ctx()
    }

    public fun scenario(env: &mut BridgeEnv): &mut Scenario {
        &mut env.scenario
    }

    public fun chain_id(env: &mut BridgeEnv): u8 {
        env.chain_id
    }

    public fun committees(env: &mut BridgeEnv): &vector<BridgeCommittee> {
        &env.committees
    }

    public fun submitter(env: &mut BridgeEnv): address {
        env.submitter
    }
    // HotPotato to access shared state
    // TODO: if the bridge is the only shared state we could remvove this
    public struct BridgeWrapper {
        bridge: Bridge,
    }

    public fun bridge(env: &mut BridgeEnv, sender: address): BridgeWrapper {
        let scenario = &mut env.scenario;
        scenario.next_tx(sender);
        let bridge = scenario.take_shared<Bridge>();
        BridgeWrapper { bridge }
    }
    
    public fun bridge_ref(wrapper: &BridgeWrapper): &Bridge {
        &wrapper.bridge
    }

    public fun bridge_ref_mut(wrapper: &mut BridgeWrapper): &mut Bridge {
        &mut wrapper.bridge
    }

    public fun return_bridge(bridge: BridgeWrapper) {
        let BridgeWrapper { bridge } = bridge;
        test_scenario::return_shared(bridge);
    }

    public fun create_env(): BridgeEnv {
        let mut scenario = test_scenario::begin(SUBMITTER);
        let ctx = test_scenario::ctx(&mut scenario);
        let otw = create_one_time_witness<SBTC>();
        sbtc::init_test(otw, ctx);

        let mut clock = sui::clock::create_for_testing(ctx);
        clock.set_for_testing(1_000_000_000);

        BridgeEnv{
            scenario,
            chain_id: chain_ids::chain_id(),
            committees: vector::empty(),
            submitter: SUBMITTER,
            clock,
        }
    }

    public fun destroy_env(env: BridgeEnv) {
        let BridgeEnv {
            scenario,
            chain_id: _,
            committees: _,
            submitter: _,
            clock,
        } = env;
        clock.destroy_for_testing();
        scenario.end();
    }

    // Add a set of committees to the chain.
    // Call only once in a test scenario.
    public fun setup_committees(
        env: &mut BridgeEnv,
        committees: vector<BridgeCommittee>,
    ) {
        let scenario = &mut env.scenario;
        scenario.next_tx(env.submitter);

        env.committees = committees;
    }

    //
    // Bridge creation and setup
    //

    // Set up an environment with 3 validators, a bridge with
    // a treasury and a committee with all 3 validators.
    // The treasury will contain 4 tokens: ETH, BTC, USDT, USDC.
    // Save the Bridge as a shared object.
    public fun create_bridge_default(env: &mut BridgeEnv) {
        let committees = vector[
            create_committee(
                3334,
                &b"1234567890_1234567890_1234567890",
            ),
            create_committee(
                3333,
                &b"234567890_1234567890_1234567890_",
            ),
            create_committee(
                3333,
                &b"34567890_1234567890_1234567890_1",
            ),
        ];
        env.setup_committees(committees);

        let sender = env.submitter;
        env.create_bridge(sender);
        env.register_committee();
        env.init_committee(sender);
        env.setup_treasury(sender);
    }

    // Create a bridge and set up a treasury.
    // The treasury will contain 4 tokens: ETH, BTC, USDT, USDC.
    // Save the Bridge as a shared object.
    // No operation on the validators.
    public fun create_bridge(env: &mut BridgeEnv, sender: address) {
        env.scenario.next_tx(sender);
        let ctx = env.scenario.ctx();
        let otw = create_one_time_witness<SBTC>();
        init_test(otw, ctx);
    }

    // Register 3 committee members (validators `@0xA`, `@0xB`, `@0xC`)
    public fun register_committee(env: &mut BridgeEnv) {
        let scenario = &mut env.scenario;
        scenario.next_tx(env.submitter);
        let mut _bridge = scenario.take_shared<Bridge>();
        let admin_cap = scenario.take_from_address<AdminCap>(env.submitter);
        scenario.next_tx(env.submitter);

        _bridge.update_submitter(&admin_cap, env.submitter, true);

        let mut committees = vector::empty();
        env
            .committees
            .do_ref!(
                |committee| {
                    committees.push_back(committee::pubkey_to_address(*committee.key_pair.public_key()))
                },
            );
        _bridge.committee_registration(
            &admin_cap,
            committees,
        );
        test_scenario::return_shared(_bridge);
        test_scenario::return_to_sender(scenario, admin_cap);
    }

    // Init the bridge committee
    public fun init_committee(env: &mut BridgeEnv, sender: address) {
        let scenario = &mut env.scenario;
        scenario.next_tx(sender);
        let mut bridge = scenario.take_shared<Bridge>();
        let mut active_committee_powers = vec_map::empty();
        env
            .committees
            .do_ref!(
                |committee| {
                    active_committee_powers.insert(committee::pubkey_to_address(*committee.key_pair.public_key()), committee.stake_amount)
                },
            );
        bridge.test_init_bridge_committee(
            active_committee_powers,
            50,
            scenario.ctx(),
        );
        test_scenario::return_shared(bridge);
    }

    // Set up a treasury with 4 tokens: ETH, BTC, USDT, USDC.
    public fun setup_treasury(env: &mut BridgeEnv, sender: address) {
        env.register_default_tokens(sender);
        env.add_default_tokens(sender);
        env.add_default_routes(sender);

        // add default bridge limit
        env.update_bridge_limit(sender,
            chain_ids::chain_id(),
            test_source_chain_id(),
            test_btc_id(),
            35000000000000
        );
        // env.load_vault(sender);
    }

    // Register 4 tokens with the Bridge: ETH, BTC, USDT, USDC.
    fun register_default_tokens(env: &mut BridgeEnv, sender: address) {
        env.scenario.next_tx(sender);
        let mut bridge = env.scenario.take_shared<Bridge>();
        let treasury_cap = env.scenario.take_from_address<TreasuryCap<SBTC>>(env.submitter);
        let metadata = env.scenario.take_immutable<CoinMetadata<SBTC>>();

        bridge.register_foreign_token<SBTC>(
            treasury_cap,
            &metadata,
        );
        destroy(metadata);

        test_scenario::return_shared(bridge);
    }
    
    // Add the 1 tokens previously registered: SBTC.
    fun add_default_tokens(env: &mut BridgeEnv, sender: address) {
        let scenario = &mut env.scenario;
        scenario.next_tx(sender);
        let mut bridge = scenario.take_shared<Bridge>();

        let add_token_message = create_add_tokens_on_sui_message(
            env.chain_id,
            bridge.get_seq_num_for(message_types::add_tokens_on_sui()),
            false,
            vector[BTC_ID],
            vector[
                type_name::get<SBTC>().into_string(),
            ],
            vector[1],
        );
        let signatures = env.sign_message(add_token_message);
        bridge.execute_system_message(add_token_message, signatures);

        test_scenario::return_shared(bridge);
    }
    
    // Add the 1 routes previously registered: source_chain SBTC.
    fun add_default_routes(env: &mut BridgeEnv, sender: address) {
        let scenario = &mut env.scenario;
        scenario.next_tx(sender);
        let mut bridge = scenario.take_shared<Bridge>();

        let add_route_message = create_add_routes_on_sui_message(
            chain_ids::chain_id(),
            bridge.get_seq_num_for(message_types::add_routes_on_sui()),
            vector[test_source_chain_id()],
            vector[test_btc_id()],
            vector[
                2000
            ],
            vector[0],
            vector[true],
        );
        let signatures = env.sign_message(add_route_message);
        bridge.execute_system_message(add_route_message, signatures);

        test_scenario::return_shared(bridge);
    }
    
    // Register new token
    public fun register_foreign_token<T>(
        env: &mut BridgeEnv,
        treasury_cap: TreasuryCap<T>,
        metadata: CoinMetadata<T>,
        sender: address,
    ) {
        // set up
        let scenario = env.scenario();
        scenario.next_tx(sender);
        let mut bridge = scenario.take_shared<Bridge>();

        // run registration
        bridge.register_foreign_token<T>(treasury_cap, &metadata);

        // verify registration events
        let register_events = event::events_by_type<TokenRegistrationEvent>();
        assert!(register_events.length() == 1);

        // verify changes in bridge
        let type_name = type_name::get<T>();
        let inner = bridge.test_load_inner();
        let treasury = inner.inner_treasury();
        let waiting_room = treasury.waiting_room();
        assert!(waiting_room.contains(type_name::into_string(type_name)));
        let treasuries = treasury.treasuries();
        assert!(treasuries.contains(type_name));

        // tear down
        test_scenario::return_shared(bridge);
        destroy(metadata);
    }

    // Blocklist a list of bridge nodes
    public fun execute_blocklist(
        env: &mut BridgeEnv,
        sender: address,
        chain_id: u8,
        blocklist_type: u8,
        validator_ecdsa_addresses: vector<vector<u8>>,
    ) {
        // set up
        let scenario = env.scenario();
        scenario.next_tx(sender);
        let mut bridge = scenario.take_shared<Bridge>();

        // message signed
        let blocklist = create_blocklist_message(
            chain_id,
            bridge.get_seq_num_for(message_types::committee_blocklist()),
            blocklist_type,
            validator_ecdsa_addresses,
        );
        let signatures = env.sign_message(blocklist);

        // run blocklist
        bridge.execute_system_message(blocklist, signatures);

        // verify blocklist events
        let block_list_events = event::events_by_type<
            BlocklistCommitteeEvent,
        >();
        assert!(
            block_list_events.length() == validator_ecdsa_addresses.length(),
        );

        // tear down
        test_scenario::return_shared(bridge);
    }


    // Add routes
    public fun add_routes(env: &mut BridgeEnv,sender: address, target_chain_id: u8, token_id: u8, fee_percentage: u64, bridge_amount: u64, supported: bool) {
        let scenario = &mut env.scenario;
        scenario.next_tx(sender);
        let mut bridge = scenario.take_shared<Bridge>();

        let add_route_message = create_add_routes_on_sui_message(
            env.chain_id(),
            bridge.get_seq_num_for(message_types::add_routes_on_sui()),
            vector[target_chain_id],
            vector[token_id],
            vector[
                fee_percentage
            ],
            vector[bridge_amount],
            vector[supported],
        );
        let signatures = env.sign_message(add_route_message);
        bridge.execute_system_message(add_route_message, signatures);

        test_scenario::return_shared(bridge);
    }

    // Update the limit for a given route
    public fun update_bridge_limit(
        env: &mut BridgeEnv,
        sender: address,
        receiving_chain: u8,
        sending_chain: u8,
        sending_token: u8,
        limit: u64,
    ): u64 {
        // set up
        let scenario = env.scenario();
        scenario.next_tx(sender);
        let mut bridge = scenario.take_shared<Bridge>();

        // message signed
        let msg = message::create_update_bridge_limit_message(
            receiving_chain,
            bridge.get_seq_num_for(message_types::update_bridge_limit()),
            sending_chain,
            sending_token,
            limit,
        );
        let signatures = env.sign_message(msg);

        // run limit update
        bridge.execute_system_message(msg, signatures);

        // verify limit events
        let limit_events = event::events_by_type<UpdateRouteLimitEvent>();
        assert!(limit_events.length() == 1);
        let event = limit_events[0];
        let (sc, st, new_limit) = event.unpack_route_limit_event();
        assert!(sc == sending_chain);
        assert!(st == sending_token);
        assert!(new_limit == limit);

        // tear down
        test_scenario::return_shared(bridge);
        new_limit
    }

    // Update a given asset price (notional value)
    public fun update_asset_price(
        env: &mut BridgeEnv,
        sender: address,
        token_id: u8,
        value: u64,
    ) {
        // set up
        let scenario = &mut env.scenario;
        scenario.next_tx(sender);
        let mut bridge = scenario.take_shared<Bridge>();

        // message signed
        let message = message::create_update_asset_price_message(
            token_id,
            env.chain_id,
            bridge.get_seq_num_for(message_types::update_asset_price()),
            value,
        );
        let signatures = env.sign_message(message);

        // run price update
        bridge.execute_system_message(message, signatures);

        // verify price events
        let update_events = event::events_by_type<UpdateTokenPriceEvent>();
        assert!(update_events.length() == 1);
        let (event_token_id, event_new_price) = update_events[
            0
        ].unwrap_update_event();
        assert!(event_token_id == token_id);
        assert!(event_new_price == value);

        // tear down
        test_scenario::return_shared(bridge);
    }

    // Add a list of tokens to the bridge.
    public fun add_tokens(
        env: &mut BridgeEnv,
        sender: address,
        native_token: bool,
        token_ids: vector<u8>,
        type_names: vector<String>,
        token_prices: vector<u64>,
    ) {
        // set up
        let scenario = &mut env.scenario;
        scenario.next_tx(sender);
        let mut bridge = scenario.take_shared<Bridge>();

        // message signed
        let message = create_add_tokens_on_sui_message(
            env.chain_id,
            bridge.get_seq_num_for(message_types::add_tokens_on_sui()),
            native_token,
            token_ids,
            type_names,
            token_prices,
        );
        let signatures = env.sign_message(message);

        // run token addition
        bridge.execute_system_message(message, signatures);

        // verify token addition events
        let new_tokens_events = event::events_by_type<NewTokenEvent>();
        assert!(new_tokens_events.length() <= token_ids.length());

        // tear down
        test_scenario::return_shared(bridge);
    }

    // Register the `TEST_TOKEN` token
    public fun register_test_token(env: &mut BridgeEnv) {
        // set up
        let scenario = &mut env.scenario;
        scenario.next_tx(@0x0);
        let mut bridge = scenario.take_shared<Bridge>();

        // "create" the `Coin`
        let (
            upgrade_cap,
            treasury_cap,
            metadata,
        ) = test_token::create_bridge_token(scenario.ctx());
        // register the coin/token with the bridge
        bridge.register_foreign_token<TEST_TOKEN>(
            treasury_cap,
            // upgrade_cap,
            &metadata,
        );

        // verify registration events
        let register_events = event::events_by_type<TokenRegistrationEvent>();
        assert!(register_events.length() == 1);
        let (type_name, decimal, nat) = register_events[
            0
        ].unwrap_registration_event();
        assert!(type_name == type_name::get<TEST_TOKEN>());
        assert!(decimal == 8);
        assert!(nat == false);

        // tear down
        destroy(upgrade_cap);
        destroy(metadata);
        test_scenario::return_shared(bridge);
    }

    public fun bridge_in_message(
        env: &mut BridgeEnv,
        source_chain: u8,
        token_type: u8,
        source_address: vector<u8>,
        target_address: address,
        amount: u64,
    ): BridgeMessage {

        let scenario = &mut env.scenario;
        scenario.next_tx(@0x0);
        let mut bridge = scenario.take_shared<Bridge>();

        let message = message::create_token_bridge_message(
            source_chain,
            bridge.get_seq_num_inc_for(message_types::token()),
            source_address,
            env.chain_id,
            address::to_bytes(target_address),
            token_type,
            amount,
        );
        test_scenario::return_shared(bridge);
        message
    }

    public fun bridge_out_message(
        env: &mut BridgeEnv,
        target_chain: u8,
        token_type: u8,
        target_address: vector<u8>,
        source_address: address,
        amount: u64,
        transfer_id: u64,
    ): BridgeMessage {

        let scenario = &mut env.scenario;
        scenario.next_tx(@0x0);
        let bridge = scenario.take_shared<Bridge>();

        let message = message::create_token_bridge_message(
            env.chain_id,
            transfer_id,
            address::to_bytes(source_address),
            target_chain,
            target_address,
            token_type,
            amount,
        );
        test_scenario::return_shared(bridge);
        message
    }

    public fun bridge_token_signed_message(
        env: &mut BridgeEnv,
        source_chain: u8,
        token_type: u8,
        source_address: vector<u8>,
        target_address: address,
        amount: u64,
    ): (BridgeMessage, vector<vector<u8>>) {
        let scenario = &mut env.scenario;
        scenario.next_tx(@0x0);
        let mut bridge = scenario.take_shared<Bridge>();
        let seq_num = bridge.get_seq_num_inc_for(message_types::token());
        test_scenario::return_shared(bridge);
        let message = message::create_token_bridge_message(
            source_chain,
            seq_num,
            source_address,
            env.chain_id,
            address::to_bytes(target_address),
            token_type,
            amount,
        );
        let signatures = env.sign_message(message);
        (message, signatures)
    }
    // Bridge the `amount` of the given `Token` from the `source_chain`.
    public fun bridge_to_sui(
        env: &mut BridgeEnv,
        source_chain: u8,
        token_type: u8,
        source_address: vector<u8>,
        target_address: address,
        amount: u64,
    ): u64 {
        // let token_type = env.token_type<Token>();

        // setup
        let scenario = &mut env.scenario;
        scenario.next_tx(env.submitter);
        let mut bridge = scenario.take_shared<Bridge>();

        // sign message
        let seq_num = bridge.get_seq_num_inc_for(message_types::token());
        let message = message::create_token_bridge_message(
            source_chain,
            seq_num,
            source_address,
            env.chain_id,
            address::to_bytes(target_address),
            token_type,
            amount,
        );
        let signatures = env.sign_message(message);

        // run approval
        bridge.approve_token_transfer(message, signatures, env.ctx());

        // verify approval events
        let approved_events = event::events_by_type<TokenTransferApproved>();
        let already_approved_events = event::events_by_type<
            TokenTransferAlreadyApproved,
        >();
        assert!(
            approved_events.length() == 1 ||
            already_approved_events.length() == 1,
        );
        let key = if (approved_events.length() == 1) {
            approved_events[0].transfer_approve_key()
        } else {
            already_approved_events[0].transfer_already_approved_key()
        };
        let (sc, mt, sn) = key.unpack_message();
        assert!(source_chain == sc);
        assert!(mt == message_types::token());
        assert!(sn == seq_num);

        // tear down
        test_scenario::return_shared(bridge);
        seq_num
    }

    // Approves a token transer
    public fun approve_token_transfer(
        env: &mut BridgeEnv,
        message: BridgeMessage,
        signatures: vector<vector<u8>>,
    ): u8 {
        let msg_key = message.key();

        // set up
        let scenario = &mut env.scenario;
        scenario.next_tx(@0x0);
        let mut bridge = scenario.take_shared<Bridge>();

        // run approval
        bridge.approve_token_transfer(message, signatures, scenario.ctx());

        // verify approval events
        let approved = event::events_by_type<TokenTransferApproved>();
        let already_approved = event::events_by_type<
            TokenTransferAlreadyApproved,
        >();
        assert!(approved.length() == 1 || already_approved.length() == 1);
        let (key, approve_status) = if (approved.length() == 1) {
            (approved[0].transfer_approve_key(), APPROVED)
        } else {
            (
                already_approved[0].transfer_already_approved_key(),
                ALREADY_APPROVED,
            )
        };
        assert!(msg_key == key);

        // tear down
        test_scenario::return_shared(bridge);
        approve_status
    }

    // Clain a token transfer and returns the coin
    public fun claim_token<T>(
        env: &mut BridgeEnv,
        sender: address,
        source_chain: u8,
        bridge_seq_num: u64,
    ): Coin<T> {
        // set up
        let scenario = &mut env.scenario;
        scenario.next_tx(sender);
        let clock = &env.clock;
        let mut bridge = scenario.take_shared<Bridge>();
        let ctx = scenario.ctx();
        let total_supply_before = get_total_supply<T>(&bridge);

        // run claim
        let token = bridge.claim_token<T>(
            clock,
            source_chain,
            bridge_seq_num,
            ctx,
        );

        // verify value change and claim events
        let token_value = token.value();
        assert!(
            total_supply_before + token_value == get_total_supply<T>(&bridge),
        );
        let claimed = event::events_by_type<TokenTransferClaimed>();
        let already_claimed = event::events_by_type<
            TokenTransferAlreadyClaimed,
        >();
        let limit_exceeded = event::events_by_type<TokenTransferLimitExceed>();
        assert!(
            claimed.length() == 1 || already_claimed.length() == 1 ||
            limit_exceeded.length() == 1,
        );
        let key = if (claimed.length() == 1) {
            claimed[0].transfer_claimed_key()
        } else if (already_claimed.length() == 1) {
            already_claimed[0].transfer_already_claimed_key()
        } else {
            limit_exceeded[0].transfer_limit_exceed_key()
        };
        let (sc, mt, sn) = key.unpack_message();
        assert!(source_chain == sc);
        assert!(mt == message_types::token());
        assert!(sn == bridge_seq_num);

        // tear down
        test_scenario::return_shared(bridge);
        token
    }

    // Claim a token and transfer to the receiver in the bridge message
    public fun claim_and_transfer_token<T>(
        env: &mut BridgeEnv,
        source_chain: u8,
        bridge_seq_num: u64,
    ): u8 {
        // set up
        let sender = @0xA1B2C3; // random sender
        let scenario = &mut env.scenario;
        scenario.next_tx(sender);
        let clock = &env.clock;
        let mut bridge = scenario.take_shared<Bridge>();
        let ctx = scenario.ctx();
        let total_supply_before = get_total_supply<T>(&bridge);

        // run claim and transfer
        bridge.claim_and_transfer_token<T>(
            clock,
            source_chain,
            bridge_seq_num,
            ctx,
        );

        // verify claim events
        let claimed = event::events_by_type<TokenTransferClaimed>();
        let already_claimed = event::events_by_type<
            TokenTransferAlreadyClaimed,
        >();
        let limit_exceeded = event::events_by_type<TokenTransferLimitExceed>();
        assert!(
            claimed.length() == 1 || already_claimed.length() == 1 ||
            limit_exceeded.length() == 1,
        );
        let (key, claim_status) = if (claimed.length() == 1) {
            (claimed[0].transfer_claimed_key(), CLAIMED)
        } else if (already_claimed.length() == 1) {
            (already_claimed[0].transfer_already_claimed_key(), ALREADY_CLAIMED)
        } else {
            (limit_exceeded[0].transfer_limit_exceed_key(), LIMIT_EXCEEDED)
        };
        let (sc, mt, sn) = key.unpack_message();
        assert!(source_chain == sc);
        assert!(mt == message_types::token());
        assert!(sn == bridge_seq_num);

        // verify effects
        let effects = scenario.next_tx(@0xABCDEF);
        let created = effects.created();
        if (!created.is_empty()) {
            let token_id = effects.created()[0];
            let token = scenario.take_from_sender_by_id<Coin<T>>(token_id);
            let token_value = token.value();
            assert!(
                total_supply_before + token_value ==
                get_total_supply<T>(&bridge),
            );
            scenario.return_to_sender(token);
        };

        // tear down
        test_scenario::return_shared(bridge);
        claim_status
    }

    // Send a coin (token) to the target chain
    public fun send_token<T>(
        env: &mut BridgeEnv,
        sender: address,
        target_chain_id: u8,
        target_token_id: u8,
        eth_address: vector<u8>,
        coin: Coin<T>,
    ): u64 {
        // set up
        let chain_id = env.chain_id;
        let scenario = env.scenario();
        scenario.next_tx(sender);
        let mut bridge = scenario.take_shared<Bridge>();
        let coin_value = coin.value();
        let total_supply_before = get_total_supply<T>(&bridge);
        let seq_num = bridge.get_seq_num_for(message_types::token());

        // run send
        let fee = coin_value * 2000/1000000;
        bridge.send_token(target_chain_id, target_token_id,eth_address, coin, scenario.ctx());
       
        // verify send events
        assert!(
            total_supply_before - coin_value == get_total_supply<T>(&bridge) - fee,
        );
        let deposited_events = event::events_by_type<TokenWithdrawEvent>();
        assert!(deposited_events.length() == 1);
        let (
            event_seq_num,
            _event_source_chain,
            _event_sender_address,
            _event_target_chain,
            _event_target_address,
            _event_token_type,
            event_amount,
        ) = deposited_events[0].unwrap_withdraw_event();
        assert!(event_seq_num == seq_num);
        assert!(event_amount == coin_value-fee);
        assert_key(chain_id, &bridge);

        // tear down
        test_scenario::return_shared(bridge);
        seq_num
    }
    //
    // Utility functions for custom behavior
    //

    // public fun token_type<T>(env: &mut BridgeEnv): u8 {
    //     env.scenario.next_tx(env.submitter);
    //     let bridge = env.scenario.take_shared<Bridge>();
    //     let inner = bridge.test_load_inner();
    //     let token_id = inner.inner_treasury().token_id<T>();
    //     test_scenario::return_shared(bridge);
    //     token_id
    // }
    
    fun sign_message(
        env: &BridgeEnv,
        message: BridgeMessage,
    ): vector<vector<u8>> {
        env
            .committees
            .map_ref!(
                |committee| {
                    secp256k1_sign(
                        committee.key_pair.private_key(),
                        &message.serialize_message(),
                        0,
                        true,
                    )
                },
            )
    }

    public fun sign_message_with(
        env: &BridgeEnv,
        message: BridgeMessage,
        committee_idxs: vector<u64>,
    ): vector<vector<u8>> {
        committee_idxs.map!(
            |idx| {
                secp256k1_sign(
                    env.committees[idx].key_pair.private_key(),
                    &message.serialize_message(),
                    0,
                    true,
                )
            },
        )
    }

    fun assert_key(chain_id: u8, bridge: &Bridge) {
        let inner = bridge.test_load_inner();
        let transfer_record = inner.inner_token_transfer_records();
        let seq_num = inner.sequence_nums()[&message_types::token()] - 1;
        let key = message::create_key(
            chain_id,
            message_types::token(),
            seq_num,
        );
        assert!(transfer_record.contains(key));
    }

    fun get_total_supply<T>(bridge: &Bridge): u64 {
        let inner = bridge.test_load_inner();
        let treasury = inner.inner_treasury();
        let treasuries = treasury.treasuries();
        let tc: &TreasuryCap<T> = &treasuries[type_name::get<T>()];
        tc.total_supply()
    }
}





#[test_only]
module bridge::test_token {
    use std::ascii;
    use std::type_name;
    use sui::address;
    use sui::coin::{CoinMetadata, TreasuryCap, create_currency};
    use sui::hex;
    use sui::package::{UpgradeCap, test_publish};
    use sui::test_utils::create_one_time_witness;

    public struct TEST_TOKEN has drop {}

    public fun create_bridge_token(
        ctx: &mut TxContext,
    ): (UpgradeCap, TreasuryCap<TEST_TOKEN>, CoinMetadata<TEST_TOKEN>) {
        let otw = create_one_time_witness<TEST_TOKEN>();
        let (treasury_cap, metadata) = create_currency(
            otw,
            8,
            b"tst",
            b"test",
            b"bridge test token",
            option::none(),
            ctx,
        );

        let type_name = type_name::get<TEST_TOKEN>();
        let address_bytes = hex::decode(
            ascii::into_bytes(type_name::get_address(&type_name)),
        );
        let coin_id = address::from_bytes(address_bytes).to_id();
        let upgrade_cap = test_publish(coin_id, ctx);

        (upgrade_cap, treasury_cap, metadata)
    }


}