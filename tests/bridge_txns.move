// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module bridge::bridge_txns;
use bridge::bridge_env::{
    already_claimed,
    claimed,
    create_bridge_default,
    create_env,
    limit_exceeded,
    test_btc_id,
    test_source_chain_id
};
use bridge::sbtc::{SBTC};

#[test]
fun test_limits() {
    let mut env = create_env();
    env.create_bridge_default();

    let source_chain = test_source_chain_id();
    let token_type = test_btc_id();
    let sui_address = @0xABCDEF;
    let eth_address = x"0000000000000000000000000000000000001234";

    // lower limits
    let chain_id = env.chain_id();
    env.update_bridge_limit(@0x0, chain_id, source_chain, test_btc_id(), 3000);
    let transfer_id1 = env.bridge_to_sui(
        source_chain,
        token_type,
        eth_address,
        sui_address,
        40000000000000,
    );
    let transfer_id2 = env.bridge_to_sui(
        source_chain,
        token_type,
        eth_address,
        sui_address,
        1000,
    );
    assert!(
        env.claim_and_transfer_token<SBTC>(source_chain, transfer_id1) ==
        limit_exceeded(),
    );
    assert!(
        env.claim_and_transfer_token<SBTC>(source_chain, transfer_id2) ==
        claimed(),
    );
    // double claim is ok and it is a no-op
    assert!(
        env.claim_and_transfer_token<SBTC>(source_chain, transfer_id2) ==
        already_claimed(),
    );

    // up limits to allow claim
    env.update_bridge_limit(@0x0, chain_id, source_chain,token_type,  4000);
    assert!(
        env.claim_and_transfer_token<SBTC>(source_chain, transfer_id1) ==
        claimed(),
    );

    env.destroy_env();
}

#[test]
fun test_bridge_and_claim() {
    let mut env = create_env();
    env.create_bridge_default();

    let source_chain = test_source_chain_id();
    let token_type = test_btc_id();
    let sui_address = @0xABCDEF;
    let eth_address = x"0000000000000000000000000000000000001234";
    let amount = 1000;

    //
    // move from eth and transfer to sui account
    let transfer_id1 = env.bridge_to_sui(
        source_chain,
        token_type,
        eth_address,
        sui_address,
        amount,
    );
    assert!(
        env.claim_and_transfer_token<SBTC>(source_chain, transfer_id1) ==
        claimed(),
    );
    let transfer_id2 = env.bridge_to_sui(
        source_chain,
        token_type,
        eth_address,
        sui_address,
        amount,
    );
    assert!(
        env.claim_and_transfer_token<SBTC>(source_chain, transfer_id2) ==
        claimed(),
    );
    // double claim is ok and it is a no-op
    assert!(
        env.claim_and_transfer_token<SBTC>(source_chain, transfer_id2) ==
        already_claimed(),
    );

    //
    // change order
    let transfer_id1 = env.bridge_to_sui(
        source_chain,
        token_type,
        eth_address,
        sui_address,
        amount,
    );
    let transfer_id2 = env.bridge_to_sui(
        source_chain,
        token_type,
        eth_address,
        sui_address,
        amount,
    );
    assert!(
        env.claim_and_transfer_token<SBTC>(source_chain, transfer_id1) ==
        claimed(),
    );
    assert!(
        env.claim_and_transfer_token<SBTC>(source_chain, transfer_id2) ==
        claimed(),
    );

    //
    // move from eth and send it back
    let transfer_id = env.bridge_to_sui(
        source_chain,
        token_type,
        eth_address,
        sui_address,
        amount,
    );
    let token = env.claim_token<SBTC>(sui_address, source_chain, transfer_id);
    env.send_token<SBTC>(
        sui_address,
        source_chain,
        token_type,
        eth_address,
        token,
    );

    env.destroy_env();
}