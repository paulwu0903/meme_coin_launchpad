module jokefun::genesis {

    use sui::package::{ Self };

    public struct GENESIS has drop {}

    fun init (otw: GENESIS, ctx: &mut TxContext){
        package::claim_and_keep(otw, ctx);
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(GENESIS{}, ctx);
    }
}