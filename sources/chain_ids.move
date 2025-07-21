// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module bridge::chain_ids {
    use sui::vec_map::{Self, VecMap};

    // Chain IDs
    const SUI_CHAIN_ID: u8 = 16;

    const EInvalidBridgeRoute: u64 = 0;
    const EInvalidBridgeRouteFeePercentage: u64 = 2;
    const EInsufficientBridgeAmount: u64 = 3;
    const ERouteNotSupported: u64 = 4;

    const PERCENTAGE_DENOMINATOR: u64 = 1000000;

    //////////////////////////////////////////////////////
    // Types
    //
    public struct BridgeSupportedRoutes has copy, drop, store {
        routes: VecMap<BridgeRoute, BridgeRouteValue>,
    }
    
    public struct BridgeRoute has copy, drop, store {
        destination: u8,
        token: u8,
    }
    
    public struct BridgeRouteValue has copy, drop, store {
        fee_percentage: u64,
        bridge_amount: u64,
        supported: bool,
        min_amount: u64,
    }


    //////////////////////////////////////////////////////
    // Internal functions
    //

    public(package) fun create(): BridgeSupportedRoutes {
        BridgeSupportedRoutes {
            routes: vec_map::empty(),
        }
    }

    public(package) fun add_new_route(
        self: &mut BridgeSupportedRoutes,
        destination: u8,
        token: u8,
        fee_percentage: u64,
        bridge_amount: u64,
        supported: bool,
        min_amount: u64
      ) {
          assert!(fee_percentage < PERCENTAGE_DENOMINATOR, EInvalidBridgeRouteFeePercentage);
          let route = BridgeRoute{
            destination,
            token,
          };
          let value = BridgeRouteValue {
            fee_percentage,
            bridge_amount,
            supported,
            min_amount,
          };
          if (self.routes.contains(&route)) {
            let _value = self.routes.get_mut(&route);
            *_value = value;
          } else {
            self.routes.insert(route, value);
          };
    }

    public(package) fun update_bridge_amount(
        self: &mut BridgeSupportedRoutes,
        route: &BridgeRoute,
        amount: u64,
        is_claim: bool
    ){
        let value = self.routes.get_mut(route);
        if (is_claim) {
          value.bridge_amount = value.bridge_amount + amount
        } else {
          assert!(value.bridge_amount >= amount, EInsufficientBridgeAmount);
          value.bridge_amount = value.bridge_amount - amount
        }
    }

    public(package) fun update_bridge_min_amount(
        self: &mut BridgeSupportedRoutes,
        route: &BridgeRoute,
        min_amount: u64
    ){
        let value = self.routes.get_mut(route);
        value.min_amount = min_amount;
    }

    public(package) fun update_bridge_fee_percentage(
        self: &mut BridgeSupportedRoutes,
        route: &BridgeRoute,
        fee_percentage: u64
    ){
        assert!(fee_percentage < PERCENTAGE_DENOMINATOR, EInvalidBridgeRouteFeePercentage);
        let value = self.routes.get_mut(route);
        value.fee_percentage = fee_percentage;
    }

    public(package) fun get_fees(
        self: &BridgeSupportedRoutes,
        route: &BridgeRoute,
        amount: u64
    ): u64{
        let value = self.routes.try_get(route);
        assert!(value.is_some(), ERouteNotSupported);
        
        let _value = value.destroy_some();
        ((_value.fee_percentage as u128) * (amount as u128) / (PERCENTAGE_DENOMINATOR as u128)) as u64
    }

    public(package) fun get_min_amount(
        self: &BridgeSupportedRoutes,
        route: &BridgeRoute
    ): u64 {
        let value = self.routes.try_get(route);
        assert!(value.is_some(), ERouteNotSupported);
        value.destroy_some().min_amount
    }
    //////////////////////////////////////////////////////
    // Public functions
    //

    public fun chain_id(): u8 { SUI_CHAIN_ID }
    // public fun sui_mainnet(): u8 { SuiMainnet }
    // public fun sui_testnet(): u8 { SuiTestnet }
    // public fun sui_custom(): u8 { SuiCustom }

    // public fun eth_mainnet(): u8 { EthMainnet }
    // public fun eth_sepolia(): u8 { EthSepolia }
    // public fun eth_custom(): u8 { EthCustom }

    // public use fun route_source as BridgeRoute.source;
    // public fun route_source(route: &BridgeRoute): &u8 {
    //     &route.source
    // }

    public use fun route_destination as BridgeRoute.destination;
    public fun route_destination(route: &BridgeRoute): &u8 {
        &route.destination
    }

    public use fun route_token as BridgeRoute.token;
    public fun route_token(route: &BridgeRoute): &u8 {
        &route.token
    }

    public fun assert_valid_chain_id(id: u8) {
        assert!(
            id == SUI_CHAIN_ID,
            EInvalidBridgeRoute
        )
    }

    // public fun valid_routes(self:&BridgeSupportedRoutes): vector<BridgeRoute> {
    //     self.routes
    // }

    public fun is_valid_route(self: &BridgeSupportedRoutes, destination: u8, token: u8): bool {
        let key = BridgeRoute { destination, token };
        let value = self.routes.try_get(&key);
        if (value.is_some()) {
          value.destroy_some().supported
        } else {
          false
        }
    }

    // Checks and return BridgeRoute if the route is supported by the bridge.
    public fun get_route(self: &BridgeSupportedRoutes, destination: u8, token: u8): BridgeRoute {
        let route = BridgeRoute { destination, token };
        assert!(self.is_valid_route(destination, token), EInvalidBridgeRoute);
        route
    }

    //////////////////////////////////////////////////////
    // Test functions
    //

    // #[test]
    // fun test_chains_ok() {
    //     assert_valid_chain_id(SuiMainnet);
    //     assert_valid_chain_id(SuiTestnet);
    //     assert_valid_chain_id(SuiCustom);
    //     assert_valid_chain_id(EthMainnet);
    //     assert_valid_chain_id(EthSepolia);
    //     assert_valid_chain_id(EthCustom);
    // }

    // #[test]
    // #[expected_failure(abort_code = EInvalidBridgeRoute)]
    // fun test_chains_error() {
    //     assert_valid_chain_id(100);
    // }

    // #[test]
    // #[expected_failure(abort_code = EInvalidBridgeRoute)]
    // fun test_sui_chains_error() {
    //     // this will break if we add one more sui chain id and should be corrected
    //     assert_valid_chain_id(4);
    // }

    // #[test]
    // #[expected_failure(abort_code = EInvalidBridgeRoute)]
    // fun test_eth_chains_error() {
    //     // this will break if we add one more eth chain id and should be corrected
    //     assert_valid_chain_id(13);
    // }

    // #[test]
    // fun test_routes() {
    //     let valid_routes = vector[
    //         BridgeRoute { source: SuiMainnet, destination: EthMainnet },
    //         BridgeRoute { source: EthMainnet, destination: SuiMainnet },

    //         BridgeRoute { source: SuiTestnet, destination: EthSepolia },
    //         BridgeRoute { source: SuiTestnet, destination: EthCustom },
    //         BridgeRoute { source: SuiCustom, destination: EthCustom },
    //         BridgeRoute { source: SuiCustom, destination: EthSepolia },
    //         BridgeRoute { source: EthSepolia, destination: SuiTestnet },
    //         BridgeRoute { source: EthSepolia, destination: SuiCustom },
    //         BridgeRoute { source: EthCustom, destination: SuiTestnet },
    //         BridgeRoute { source: EthCustom, destination: SuiCustom }
    //     ];
    //     let mut size = valid_routes.length();
    //     while (size > 0) {
    //         size = size - 1;
    //         let route = valid_routes[size];
    //         assert!(is_valid_route(route.source, route.destination)); // sould not assert
    //     }
    // }

    // #[test]
    // #[expected_failure(abort_code = EInvalidBridgeRoute)]
    // fun test_routes_err_sui_1() {
    //     get_route(SuiMainnet, SuiMainnet);
    // }

    // #[test]
    // #[expected_failure(abort_code = EInvalidBridgeRoute)]
    // fun test_routes_err_sui_2() {
    //     get_route(SuiMainnet, SuiTestnet);
    // }

    // #[test]
    // #[expected_failure(abort_code = EInvalidBridgeRoute)]
    // fun test_routes_err_sui_3() {
    //     get_route(SuiMainnet, EthSepolia);
    // }

    // #[test]
    // #[expected_failure(abort_code = EInvalidBridgeRoute)]
    // fun test_routes_err_sui_4() {
    //     get_route(SuiMainnet, EthCustom);
    // }

    // #[test]
    // #[expected_failure(abort_code = EInvalidBridgeRoute)]
    // fun test_routes_err_eth_1() {
    //     get_route(EthMainnet, EthMainnet);
    // }

    // #[test]
    // #[expected_failure(abort_code = EInvalidBridgeRoute)]
    // fun test_routes_err_eth_2() {
    //     get_route(EthMainnet, EthCustom);
    // }

    // #[test]
    // #[expected_failure(abort_code = EInvalidBridgeRoute)]
    // fun test_routes_err_eth_3() {
    //     get_route(EthMainnet, SuiCustom);
    // }

    // #[test]
    // #[expected_failure(abort_code = EInvalidBridgeRoute)]
    // fun test_routes_err_eth_4() {
    //     get_route(EthMainnet, SuiTestnet);
    // }
}
