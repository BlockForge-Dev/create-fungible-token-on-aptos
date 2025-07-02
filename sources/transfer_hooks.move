module aptos_asset::transfer_hooks {
    use aptos_framework::fungible_asset;
    use aptos_framework::object;
    use aptos_framework::primary_fungible_store;
    use std::error;
    use std::signer;
    use std::option; // ❗ Required for `option::some`

    use aptos_asset::fungible_asset::{FungibleAsset, Metadata}; // ✅ No `Self` (already aliased)
    use aptos_asset::account_control;


    /// Fee configuration for the token
    struct FeeConfig has key {
        burn_percentage: u64,  // Basis points (500 = 5%)
        fee_recipient: address,
        fee_collector_cap: fungible_asset::TransferRef
    }

    /// Error codes
    const ENOT_TOKEN_ADMIN: u64 = 1000;
    const EHOOK_NOT_ENABLED: u64 = 1001;
    const EINVALID_FEE_CONFIG: u64 = 1002;

    // ========== Admin Functions ==========

    /// Initialize transfer hooks for the token
    public entry fun initialize(
        admin: &signer,
        token: Object<Metadata>,
        burn_percentage: u64,
        fee_recipient: address
    ) acquires FeeConfig {
        assert!(
            object::is_owner(token, signer::address_of(admin)),
            error::permission_denied(ENOT_TOKEN_ADMIN)
        );
        assert!(burn_percentage <= 10_000, error::invalid_argument(EINVALID_FEE_CONFIG));

        let transfer_ref = fungible_asset::generate_transfer_ref(&object::object_address(&token));
        move_to(
            admin,
            FeeConfig {
                burn_percentage,
                fee_recipient,
                fee_collector_cap: transfer_ref
            }
        );

        // Enable transfer hook on the token
        fungible_asset::set_transfer_hook(
            &object::generate_signer(&object::object_address(&token)),
            option::some(b"apply_transfer_fee")
        );
    }

    // ========== Hook Implementation ==========

    /// The actual transfer hook that gets called on every transfer
    public fun apply_transfer_fee(
        token: Object<Metadata>,
        from: address,
        to: address,
        amount: u64
    ) acquires FeeConfig {
        // Skip fees for certain privileged operations
        if (is_exempt_transfer(from, to)) return;

        let fee_config = borrow_global<FeeConfig>(object::object_address(&token));
        let fee_amount = (amount * fee_config.burn_percentage) / 10_000;
        let remaining_amount = amount - fee_amount;

        // Process the burn
        if (fee_amount > 0) {
            let from_store = primary_fungible_store::primary_store(from, token);
            let fa = fungible_asset::withdraw_with_ref(
                &fee_config.fee_collector_cap,
                from_store,
                fee_amount
            );
            fungible_asset::burn(&fa);
        };

        // Continue with original transfer
        let from_store = primary_fungible_store::primary_store(from, token);
        let to_store = primary_fungible_store::ensure_primary_store_exists(to, token);
        fungible_asset::transfer_with_ref(
            &fee_config.fee_collector_cap,
            from_store,
            to_store,
            remaining_amount
        );
    }

    // ========== Utility Functions ==========

    /// Check if transfer should be exempt from fees (admin ops, contract interactions)
    fun is_exempt_transfer(from: address, to: address): bool {
        // Example exemptions:
        // 1. Mint/burn addresses
        // 2. Contract-controlled addresses
        // 3. Fee recipient itself
        false // Default to no exemptions
    }

    /// Update fee configuration
    public entry fun update_fee_config(
        admin: &signer,
        token: Object<Metadata>,
        new_burn_percentage: u64,
        new_fee_recipient: address
    ) acquires FeeConfig {
        assert!(
            object::is_owner(token, signer::address_of(admin)),
            error::permission_denied(ENOT_TOKEN_ADMIN)
        );
        assert!(new_burn_percentage <= 10_000, error::invalid_argument(EINVALID_FEE_CONFIG));

        let fee_config = borrow_global_mut<FeeConfig>(object::object_address(&token));
        fee_config.burn_percentage = new_burn_percentage;
        fee_config.fee_recipient = new_fee_recipient;
    }

    // ========== View Functions ==========

    /// Get current fee configuration
    public fun get_fee_config(token: Object<Metadata>): (u64, address) acquires FeeConfig {
        let fee_config = borrow_global<FeeConfig>(object::object_address(&token));
        (fee_config.burn_percentage, fee_config.fee_recipient)
    }
}