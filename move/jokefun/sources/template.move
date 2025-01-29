module jokefun::template{
    
    use sui::{
        coin::{Self, Coin, TreasuryCap},
        url::{Self, Url},
        balance::{Balance},
        sui::{SUI},
        dynamic_object_field as dof,
    };

    public struct TEMPLATE has drop{}

    const TOTAL_SUPPLY: u64 = 100;
    const DECIMALS: u8 = 9;
    const SYMBOL: vector<u8> = b"Symbol";
    const NAME: vector<u8> = b"Name";
    const DESCRIPTION: vector<u8> = b"Description";
    const ICON_URL: vector<u8> = b"icon_url";
    const MINT_PRICE: u64 = 1000;
    const OWNER_OWNED_AMOUNT: u64 = 10000;
    
    // error
    const EBalanceNotEnough: u64 = 0;
    const EMintPoolBalanceNotEnough: u64 = 1;

    public struct ProtectedTreasury has key{
        id: UID
    }

    public struct SaleCondition has store{
        mint_price: u64, //unit: mist
        platform_bps: u64,
        platform_receiver : address,
        owner_owned: u64,
        owner : address,
    }

    public struct MintPool has key {
        id: UID,
        balance: Balance<TEMPLATE>,
        condition: SaleCondition,
    }

    public struct TreasuryCapKey has copy, store, drop{}


    fun init (otw: TEMPLATE, ctx: &mut TxContext){
        let (protected_treasury, mint_pool) = create_coin_and_mint_pool(otw, TOTAL_SUPPLY, MINT_PRICE, OWNER_OWNED_AMOUNT, ctx);
        transfer::share_object(protected_treasury);
        transfer::share_object(mint_pool);
    }

    #[allow(lint(self_transfer))]
    public fun mint(
        mint_pool: &mut MintPool,
        mut coin: Coin<SUI>,
        mint_amount: u64,
        ctx: &mut TxContext,
    ){
        assert_if_mint_pool_amount_not_enough(mint_pool, mint_amount);
        assert_if_balance_not_enough(mint_pool, &coin, mint_amount);
        pay_platform_fee(mint_pool, &mut coin, ctx);
        transfer::public_transfer(coin, mint_pool.condition.owner);
        let output_coin = coin::from_balance<TEMPLATE>(mint_pool.balance.split(mint_amount), ctx);
        transfer::public_transfer(output_coin, ctx.sender());
    }

    fun create_coin_and_mint_pool(
        otw: TEMPLATE,
        mint_amount: u64,
        mint_price: u64,
        owner_owned_amount:u64,
        ctx: &mut TxContext,
    ): (ProtectedTreasury, MintPool){
        let (mut treasury_cap, coin_metadata) = coin::create_currency<TEMPLATE>(
            otw,
            DECIMALS,
            SYMBOL,
            NAME,
            DESCRIPTION,
            option::some<Url>(url::new_unsafe_from_bytes(ICON_URL)),
            ctx,
        );

        let total_coin = coin::mint<TEMPLATE>(&mut treasury_cap, mint_amount, ctx);
        
        let mut protected_treasury = ProtectedTreasury{
            id: object::new(ctx),
        };

        dof::add<TreasuryCapKey, TreasuryCap<TEMPLATE>>(
            &mut protected_treasury.id,
            TreasuryCapKey{},
            treasury_cap,
        );

        let mint_pool = create_and_fill_mint_pool(total_coin, mint_price, owner_owned_amount, ctx);

        transfer::public_freeze_object(coin_metadata);

        (protected_treasury, mint_pool)
    }

    #[allow(lint(self_transfer))]
    fun create_and_fill_mint_pool(
        mut coin: Coin<TEMPLATE>,
        mint_price: u64,
        owner_owned: u64,
        ctx: &mut TxContext,
    ): MintPool{

        let to_owner = coin.split(owner_owned, ctx);
        let mint_pool = MintPool{
            id: object::new(ctx),
            balance: coin.into_balance(),
            condition: SaleCondition{
                mint_price,
                platform_bps: 1000,
                platform_receiver: @0x39dfa26ecaf49a466cfe33b2e98de9b46425eec170e59eb40d3f69d061a67778,
                owner_owned,
                owner: ctx.sender(),
            },
        };
        transfer::public_transfer(to_owner, ctx.sender());
        mint_pool
    }

    fun pay_platform_fee(
        mint_pool: &MintPool,
        coin: &mut Coin<SUI>,
        ctx: &mut TxContext,
    ){
        let platform_fee_amount = ceil(coin.value(), mint_pool.condition.platform_bps, 10000);
        let platform_fee = coin.split(platform_fee_amount, ctx);
        transfer::public_transfer(platform_fee, mint_pool.condition.platform_receiver);
    }

    public fun ceil(
        amount: u64,
        part: u64,
        base: u64,
    ): u64{
        (((amount as u128) * (part as u128) + ((base - 1) as u128))/ (base as u128)) as u64
    }

    fun assert_if_balance_not_enough(
        mint_pool: &MintPool, 
        coin: &Coin<SUI>,
        mint_amount: u64,
    ){  
        let need_to_pay = ((mint_pool.condition.mint_price as u128) * (mint_amount as u128)) as u64;
        assert!( need_to_pay == coin.value(), EBalanceNotEnough );
    }

    fun assert_if_mint_pool_amount_not_enough(
        mint_pool: &MintPool,
        mint_amount: u64,
    ){
        let remaining_amount = mint_pool.balance.value();
        assert!(mint_amount <= remaining_amount, EMintPoolBalanceNotEnough);
    }
}