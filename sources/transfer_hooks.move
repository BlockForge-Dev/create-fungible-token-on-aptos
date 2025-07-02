module aptos_asset::transfer_hooks {
    use aptos_framework::fungible_asset::{TransferRef, BurnRef, Metadata, withdraw_with_ref, deposit_with_ref, burn};
    use aptos_framework::object::Object;
    use aptos_framework::primary_fungible_store;
    use std::error;

    const EZERO_AMOUNT: u64 = 0xE10;
    const EINVALID_FEE: u64 = 0xE11;

    const DEFAULT_FEE_BASIS_POINTS: u64 = 50; // 0.5%
    const DEFAULT_BURN_BASIS_POINTS: u64 = 20; // 0.2%
    const FEE_COLLECTOR: address = @0x123;

    public fun transfer_with_hook(
        _admin: &signer,
        asset: Object<Metadata>,
        burn_ref: &BurnRef,
        transfer_ref: &TransferRef,
        sender: address,
        recipient: address,
        amount: u64
    ) {
        assert!(amount > 0, error::invalid_argument(EZERO_AMOUNT));

        let sender_wallet = primary_fungible_store::primary_store(sender, asset);
        let recipient_wallet = primary_fungible_store::ensure_primary_store_exists(recipient, asset);
        let fee_wallet = primary_fungible_store::ensure_primary_store_exists(FEE_COLLECTOR, asset);

        let fee_amount = compute_fee(amount);
        let burn_amount = compute_burn(amount);
        let transfer_amount = amount - fee_amount - burn_amount;

        assert!(transfer_amount > 0, error::invalid_argument(EINVALID_FEE));

        // Withdraw and apply burn
        let burn_part = withdraw_with_ref(transfer_ref, sender_wallet, burn_amount);
        burn(burn_ref, burn_part);

        // Withdraw and deposit fee
        let fee_part = withdraw_with_ref(transfer_ref, sender_wallet, fee_amount);
        deposit_with_ref(transfer_ref, fee_wallet, fee_part);

        // Withdraw and send to recipient
        let user_part = withdraw_with_ref(transfer_ref, sender_wallet, transfer_amount);
        deposit_with_ref(transfer_ref, recipient_wallet, user_part);
    }

    fun compute_fee(amount: u64): u64 {
        (amount * DEFAULT_FEE_BASIS_POINTS) / 10_000
    }

    fun compute_burn(amount: u64): u64 {
        (amount * DEFAULT_BURN_BASIS_POINTS) / 10_000
    }
}
