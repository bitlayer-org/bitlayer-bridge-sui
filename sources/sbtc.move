module bridge::sbtc {
    use bridge::bridge::initializer;
    use sui::coin::create_currency;

    public struct SBTC has drop {}

    fun init(
        otw: SBTC,
        ctx: &mut TxContext,
    ) {
        let (treasury_cap, metadata) = create_currency(
            otw,
            10,
            b"sBTC",
            b"Sui Bitcoin",
            b"Sui bridge Bitcoin token",
            option::none(),
            ctx,
        );
        transfer::public_transfer(treasury_cap, ctx.sender());
        transfer::public_freeze_object(metadata);
        initializer(ctx)
    }

    #[test_only]
    public fun init_test(otw: SBTC,
        ctx: &mut TxContext,){
        init(otw, ctx)
    }
}
