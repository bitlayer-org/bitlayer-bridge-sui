module bridge::ybtc {
    use bridge::bridge::initializer;
    use sui::coin::create_currency;

    public struct YBTC has drop {}

    fun init(
        otw: YBTC,
        ctx: &mut TxContext,
    ) {
        let (treasury_cap, metadata) = create_currency(
            otw,
            8,
            b"YBTC",
            b"Yield Bitcoin",
            b"Yield bridge Bitcoin token",
            option::none(),
            ctx,
        );
        transfer::public_transfer(treasury_cap, ctx.sender());
        transfer::public_freeze_object(metadata);
        initializer(ctx)
    }

    #[test_only]
    public fun init_test(otw: YBTC,
        ctx: &mut TxContext,){
        init(otw, ctx)
    }
}
