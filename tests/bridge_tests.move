// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module bridge::bridge_tests;


use bridge::bridge::{
    inner_limiter,
    inner_paused,
    inner_treasury,
    inner_token_transfer_records_mut,
    new_bridge_record_for_testing,
    new_for_testing,
    test_get_current_seq_num_and_increment,
    test_execute_update_asset_price,
    test_get_token_transfer_action_signatures,
    test_load_inner,
    test_load_inner_mut,
    test_get_token_transfer_action_status,
    transfer_status_approved,
    transfer_status_claimed,
    transfer_status_not_found,
    transfer_status_pending,
    Bridge
};
use bridge::sbtc::{SBTC};
use bridge::bridge_env::{
    test_btc_id,
    test_source_chain_id,
    create_bridge,
    create_bridge_default,
    create_env,
    freeze_bridge,
    init_committee,
    register_committee,
    unfreeze_bridge,
};
use bridge::chain_ids;
use bridge::message::{Self, to_parsed_token_transfer_message};
use bridge::message_types;
use bridge::test_token::{TEST_TOKEN, create_bridge_token as create_test_token};
use std::type_name;
use sui::address;
use sui::balance;
use sui::coin::{Self};
use sui::hex;
// use sui::package::test_publish;
use sui::test_scenario;
use sui::test_utils::destroy;

// use bridge::bridge_env::{
//     btc_id,
//     create_bridge,
//     create_bridge_default,
//     create_env,
//     // create_validator,
//     eth_id,
//     freeze_bridge,
//     init_committee,
//     register_committee,
//     unfreeze_bridge,
//     test_btc_id
// };

// common error start code for unexpected errors in tests (assertions).
// If more than one assert in a test needs to use an unexpected error code,
// use this as the starting error and add 1 to subsequent errors
const UNEXPECTED_ERROR: u64 = 10293847;
// use on tests that fail to save cleanup
const TEST_DONE: u64 = 74839201;

#[test]
fun test_bridge_create() {
    let mut env = create_env();
    env.create_bridge(@0x0);

    let bridge = env.bridge(@0x0);
    let inner = bridge.bridge_ref().test_load_inner();
    inner.assert_not_paused(UNEXPECTED_ERROR);
    assert!(inner.inner_token_transfer_records().length() == 0);
    bridge.return_bridge();

    env.destroy_env();
}


#[test]
fun test_create_bridge_default() {
    let mut env = create_env();
    env.create_bridge_default();
    env.destroy_env();
}

#[test]
fun test_init_committee_twice() {
    let mut env = create_env();
    env.create_bridge_default();
    env.init_committee(@0x0); // second time is a no-op

    env.destroy_env();
}

#[test]
#[expected_failure(abort_code = bridge::committee::ECommitteeAlreadyInitiated)]
fun test_register_committee_after_init() {
    let mut env = create_env();
    env.create_bridge_default();
    env.register_committee();

    abort TEST_DONE
}

#[test]
fun test_register_foreign_token() {
    let addr = @0x0;
    let mut env = create_env();
    env.create_bridge_default();
    let (upgrade_cap, treasury_cap, metadata) = create_test_token(env
        .scenario()
        .ctx());

    env.register_foreign_token<TEST_TOKEN>(
        treasury_cap,
        metadata,
        addr
    );
    
    destroy(upgrade_cap);
    env.destroy_env();
}

#[test]
#[expected_failure(abort_code = bridge::treasury::ETokenSupplyNonZero)]
fun test_register_foreign_token_non_zero_supply() {
    let addr = @0x0;
    let mut env = create_env();
    env.create_bridge_default();
    let (upgrade_cap, mut treasury_cap, metadata) = create_test_token(env
        .scenario()
        .ctx());
    let _coin = treasury_cap.mint(1, env.scenario().ctx());
    env.register_foreign_token<TEST_TOKEN>(
        treasury_cap,
        metadata,
        addr
    );

    destroy(upgrade_cap);
    abort 0
}


#[test]
#[expected_failure(abort_code = bridge::treasury::EInvalidNotionalValue)]
fun test_add_token_price_zero_value() {
    let addr = @0x0;
    let mut env = create_env();
    env.create_bridge_default();
    env.add_tokens(
        addr,
        false,
        vector[test_btc_id()],
        vector[type_name::get<TEST_TOKEN>().into_string()],
        vector[0],
    );

    abort 0
}



#[test]
#[expected_failure(abort_code = bridge::bridge::EMalformedMessageError)]
fun test_add_token_malformed_1() {
    let addr = @0x0;
    let mut env = create_env();
    env.create_bridge_default();
    env.add_tokens(
        addr,
        false,
        vector[test_btc_id(), 6],
        vector[type_name::get<TEST_TOKEN>().into_string()],
        vector[10],
    );

    abort 0
}

#[test]
#[expected_failure(abort_code = bridge::bridge::EMalformedMessageError)]
fun test_add_token_malformed_2() {
    let addr = @0x0;
    let mut env = create_env();
    env.create_bridge_default();
    env.add_tokens(
        addr,
        false,
        vector[test_btc_id()],
        vector[
            type_name::get<TEST_TOKEN>().into_string(),
            type_name::get<SBTC>().into_string(),
        ],
        vector[10],
    );

    abort 0
}

#[test]
#[expected_failure(abort_code = bridge::bridge::EMalformedMessageError)]
fun test_add_token_malformed_3() {
    let addr = @0x0;
    let mut env = create_env();
    env.create_bridge_default();
    env.add_tokens(
        addr,
        false,
        vector[test_btc_id()],
        vector[type_name::get<TEST_TOKEN>().into_string()],
        vector[10, 20],
    );

    abort 0
}

#[test]
fun test_add_native_token_nop() {
    // adding a native token is simply a NO-OP at the moment
    let addr = @0x0;
    let mut env = create_env();
    env.create_bridge_default();
    env.add_tokens(
        addr,
        true,
        vector[test_btc_id()],
        vector[type_name::get<TEST_TOKEN>().into_string()],
        vector[100],
    );
    env.destroy_env();
}



#[test]
#[expected_failure(abort_code = bridge::message::EEmptyList)]
fun test_system_msg_incorrect_chain_id() {
    let sender = @0x0;
    let mut env = create_env();
    env.create_bridge_default();
    env.execute_blocklist(sender, chain_ids::chain_id(), 0, vector[]);

    abort TEST_DONE
}

#[test]
fun test_get_seq_num_and_increment() {
    let mut scenario = test_scenario::begin(@0x0);
    let ctx = scenario.ctx();
    let chain_id = chain_ids::chain_id();
    let mut bridge = new_for_testing(chain_id, ctx);

    let inner = bridge.test_load_inner_mut();
    assert!(
        inner.test_get_current_seq_num_and_increment(
            message_types::committee_blocklist(),
        ) ==
        0,
    );
    assert!(
        inner.sequence_nums()[&message_types::committee_blocklist()] == 1,
    );
    assert!(
        inner.test_get_current_seq_num_and_increment(
            message_types::committee_blocklist(),
        ) ==
        1,
    );
    // other message type nonce does not change
    assert!(
        !inner.sequence_nums().contains(&message_types::token()),
    );
    assert!(
        !inner.sequence_nums().contains(&message_types::emergency_op()),
    );
    assert!(
        !inner.sequence_nums().contains(&message_types::update_bridge_limit()),
    );
    assert!(
        !inner.sequence_nums().contains(&message_types::update_asset_price()),
    );
    assert!(
        inner.test_get_current_seq_num_and_increment(message_types::token()) ==
        0,
    );
    assert!(
        inner.test_get_current_seq_num_and_increment(
            message_types::emergency_op(),
        ) ==
        0,
    );
    assert!(
        inner.test_get_current_seq_num_and_increment(
            message_types::update_bridge_limit(),
        ) ==
        0,
    );
    assert!(
        inner.test_get_current_seq_num_and_increment(
            message_types::update_asset_price(),
        ) ==
        0,
    );

    destroy(bridge);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = bridge::chain_ids::EInvalidBridgeRoute)]
fun test_add_route_invalid() {
    let mut env = create_env();
    env.create_bridge_default();
    let bridge = env.bridge(@0x0);
    let inner = bridge.bridge_ref().test_load_inner();
    // let routes = &inner.inner_routes()
    // routes.add_new_route(1, 2, 2000, 10000000000000, true);
    let destination = 1;
    let token_id = 2;
    inner.inner_routes().get_route(destination, token_id);
    
    destroy(bridge);
    env.destroy_env();
}

#[test]
fun test_add_route() {
    let addr = @0x0;
    let mut env = create_env();
    env.create_bridge_default();

    let destination = 1;
    let token_id = 2;

    env.add_routes(addr, destination, token_id, 2000, 10000000000000, true);
    
    env.destroy_env();
}

#[test]
fun test_update_limit() {
    let mut env = create_env();
    env.create_bridge_default();

    // update limit
    env.update_bridge_limit(
        @0x0,
        chain_ids::chain_id(),
        test_source_chain_id(),
        test_btc_id(),
        1,
    );

    let bridge = env.bridge(@0x0);
    let inner = bridge.bridge_ref().test_load_inner();
    assert!(
        inner
            .inner_limiter()
            .get_route_limit(
                &chain_ids::get_route(
                    inner.inner_routes(),
                    test_source_chain_id(),
                    test_btc_id(),
                ),
            ) ==
        1,
    );
    bridge.return_bridge();

    env.destroy_env();
}

#[test]
fun test_update_asset_price() {
    let mut env = create_env();
    env.create_bridge_default();
    let scenario = env.scenario();
    scenario.next_tx(@0x0);
    let mut bridge = scenario.take_shared<Bridge>();
    let inner = bridge.test_load_inner_mut();

    // Assert the starting limit is a different value
    assert!(
        inner.inner_treasury().notional_value<SBTC>() != 1_001_000_000,
    );
    // now change it to 100_001_000
    let msg = message::create_update_asset_price_message(
        test_btc_id(),
        chain_ids::chain_id(),
        0,
        1_001_000_000,
    );
    let payload = msg.extract_update_asset_price();
    inner.test_execute_update_asset_price(payload);

    // should be 1_001_000_000 now
    assert!(inner.inner_treasury().notional_value<SBTC>() == 1_001_000_000);

    destroy(bridge);
    env.destroy_env();
}

#[test]
#[expected_failure(abort_code = bridge::treasury::EInvalidNotionalValue)]
fun test_invalid_price_update() {
    let mut env = create_env();
    env.create_bridge_default();
    env.update_asset_price(@0x0, test_btc_id(), 0);

    abort 0
}

#[test]
#[expected_failure(abort_code = bridge::treasury::EUnsupportedTokenType)]
fun test_unsupported_token_type() {
    let mut env = create_env();
    env.create_bridge_default();
    env.update_asset_price(@0x0, 42, 100);

    abort 0
}

#[test]
fun test_execute_freeze_unfreeze() {
    let mut env = create_env();
    env.create_bridge_default();
    env.freeze_bridge(@0x0, UNEXPECTED_ERROR + 1);
    let bridge = env.bridge(@0x0);
    assert!(bridge.bridge_ref().test_load_inner().inner_paused());
    bridge.return_bridge();
    env.unfreeze_bridge(@0x0, UNEXPECTED_ERROR + 2);
    let bridge = env.bridge(@0x0);
    assert!(!bridge.bridge_ref().test_load_inner().inner_paused());
    bridge.return_bridge();
    env.destroy_env();
}

#[test]
#[expected_failure(abort_code = bridge::bridge::EBridgeNotPaused)]
fun test_execute_unfreeze_err() {
    let mut env = create_env();
    env.create_bridge_default();
    let bridge = env.bridge(@0x0);
    assert!(!bridge.bridge_ref().test_load_inner().inner_paused());
    bridge.return_bridge();
    env.unfreeze_bridge(@0x0, UNEXPECTED_ERROR + 2);

    abort TEST_DONE
}

#[test]
#[expected_failure(abort_code = bridge::bridge::EBridgeAlreadyPaused)]
fun test_execute_emergency_op_abort_when_already_frozen() {
    let mut env = create_env();
    env.create_bridge_default();

    // initially it's unfrozen
    let bridge = env.bridge(@0x0);
    assert!(!bridge.bridge_ref().test_load_inner().inner_paused());
    bridge.return_bridge();
    // freeze it
    env.freeze_bridge(@0x0, UNEXPECTED_ERROR);
    let bridge = env.bridge(@0x0);
    assert!(bridge.bridge_ref().test_load_inner().inner_paused());
    bridge.return_bridge();
    // freeze it again, should abort
    env.freeze_bridge(@0x0, UNEXPECTED_ERROR);

    abort TEST_DONE
}

#[test]
fun test_get_token_transfer_action_data() {
    let mut scenario = test_scenario::begin(@0x0);
    let ctx = scenario.ctx();
    let chain_id = chain_ids::chain_id();
    let mut bridge = new_for_testing(chain_id, ctx);
    let coin = coin::mint_for_testing<SBTC>(12345, ctx);

    // Test when pending
    let message = message::create_token_bridge_message(
        chain_ids::chain_id(), // source chain
        10, // seq_num
        address::to_bytes(ctx.sender()), // sender address
        test_source_chain_id(), // target_chain
        hex::decode(
            b"00000000000000000000000000000000000000c8",
        ), // target_address
        test_btc_id(), // token_type
        coin.balance().value(),
    );

    let key = message.key();
    bridge
        .test_load_inner_mut()
        .inner_token_transfer_records_mut()
        .push_back(
            key,
            new_bridge_record_for_testing(message, option::none(), false),
        );
    assert!(
        bridge.test_get_token_transfer_action_status(chain_id, 10) ==
        transfer_status_pending(),
    );
    assert!(
        bridge.test_get_token_transfer_action_signatures(chain_id, 10) ==
        option::none(),
    );

    // Test when ready for claim
    let message = message::create_token_bridge_message(
        chain_ids::chain_id(), // source chain
        11, // seq_num
        address::to_bytes(ctx.sender()), // sender address
        test_source_chain_id(), // target_chain
        hex::decode(
            b"00000000000000000000000000000000000000c8",
        ), // target_address
        test_btc_id(), // token_type
        balance::value(coin::balance(&coin)),
    );
    let key = message.key();
    bridge
        .test_load_inner_mut()
        .inner_token_transfer_records_mut()
        .push_back(
            key,
            new_bridge_record_for_testing(
                message,
                option::some(vector[]),
                false,
            ),
        );
    assert!(
        bridge.test_get_token_transfer_action_status(chain_id, 11) ==
        transfer_status_approved(),
    );
    assert!(
        bridge.test_get_token_transfer_action_signatures(chain_id, 11) ==
        option::some(vector[]),
    );
    assert!(
        bridge.test_get_parsed_token_transfer_message(chain_id, 11) ==
        option::some(
            to_parsed_token_transfer_message(&message),
        ),
    );

    // Test when already claimed
    let message = message::create_token_bridge_message(
        chain_ids::chain_id(), // source chain
        12, // seq_num
        address::to_bytes(ctx.sender()), // sender address
        test_source_chain_id(), // target_chain
        hex::decode(
            b"00000000000000000000000000000000000000c8",
        ), // target_address
        test_btc_id(), // token_type
        balance::value(coin::balance(&coin)),
    );
    let key = message.key();
    bridge
        .test_load_inner_mut()
        .inner_token_transfer_records_mut()
        .push_back(
            key,
            new_bridge_record_for_testing(
                message,
                option::some(vector[b"1234"]),
                true,
            ),
        );
    assert!(
        bridge.test_get_token_transfer_action_status(chain_id, 12) ==
        transfer_status_claimed(),
    );
    assert!(
        bridge.test_get_token_transfer_action_signatures(chain_id, 12) ==
        option::some(vector[b"1234"]),
    );
    assert!(
        bridge.test_get_parsed_token_transfer_message(chain_id, 12) ==
        option::some(
            to_parsed_token_transfer_message(&message),
        ),
    );

    // Test when message not found
    assert!(
        bridge.test_get_token_transfer_action_status(chain_id, 13) ==
        transfer_status_not_found(),
    );
    assert!(
        bridge.test_get_token_transfer_action_signatures(chain_id, 13) ==
        option::none(),
    );
    assert!(
        bridge.test_get_parsed_token_transfer_message(chain_id, 13) ==
        option::none(),
    );

    destroy(bridge);
    coin.burn_for_testing();
    scenario.end();
}

#[test]
#[expected_failure(abort_code = bridge::treasury::EUnsupportedTokenType)]
fun test_get_metadata_no_token() {
    let mut env = create_env();
    env.create_bridge_default();
    let bridge = env.bridge(@0x0);
    let treasury = bridge.bridge_ref().test_load_inner().inner_treasury();
    treasury.notional_value<TEST_TOKEN>();

    abort 0
}
