
module aptos_asset::fungible_asset{

    
    use aptos_framework::fungible_asset::{Self, MintRef, TransferRef, BurnRef, Metadata, FungibleAsset};
    use aptos_framework::object::{Self, Object};
    use aptos_framework::primary_fungible_store;
    use std::error;
    use std::signer;
    use std::string::utf8;
    use std::option;
    use aptos_asset::account_control;


    /// Only fungible asset metadata owner can make changes.
    const ENOT_OWNER: u64 = 1;

    /// Error when trying to mint beyond the max supply
const ECAP_EXCEEDED: u64 = 0xE1;

/// Error when trying to reduce cap below already minted amount
const ECAP_LOWER_THAN_EMITTED: u64 = 0xE2;

    const ASSET_SYMBOL: vector<u8> = b"BLOCKFORGE";
    

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    /// Hold refs to control the minting, transfer and burning of fungible assets.
    struct ManagedFungibleAsset has key {
        mint_ref: MintRef,
        transfer_ref: TransferRef,
        burn_ref: BurnRef,
    }

        /// Tracks max supply (cap) and how much has been minted so far
struct EmissionState has key {
    max_supply: u64,
    total_emitted: u64,
}

        /// Capability to mint new tokens
    struct MintCapability has key {}

    /// Capability to burn tokens
    struct BurnCapability has key {}

    /// Capability to freeze/unfreeze accounts
    struct FreezeCapability has key {}
    struct UnfreezeCapability has key {}

    //Capability to withdraw tokens
    struct WithdrawCapability has key {}


    //Capability to deposit token
    struct DepositCapability has key {}



    /// Initialize metadata object and store the refs.
    // :!:>initialize
    fun init_module(admin: &signer) {
        let constructor_ref = &object::create_named_object(admin, ASSET_SYMBOL);
        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            constructor_ref,
            option::none(),
            utf8(b"BLOCKFORGE Coin"), /* name */
            utf8(ASSET_SYMBOL), /* symbol */
            8, /* decimals */
            utf8(b"https://drive.google.com/file/d/1vFm-kF6O3onxPgFJ_rVLh9YGFT_fFWM6/view?usp=sharing"), /* icon */
            utf8(b"http://metaschool.so"), /* project */
        );

        // Create mint/burn/transfer refs to allow creator to manage the fungible asset.
        let mint_ref = fungible_asset::generate_mint_ref(constructor_ref);
        let burn_ref = fungible_asset::generate_burn_ref(constructor_ref);
        let transfer_ref = fungible_asset::generate_transfer_ref(constructor_ref);
        let metadata_object_signer = object::generate_signer(constructor_ref);
        move_to(
            &metadata_object_signer,
            ManagedFungibleAsset { mint_ref, transfer_ref, burn_ref }
        );
        move_to(admin, EmissionState {
    max_supply: 0,        // Start at zero. Admin will set it later.
    total_emitted: 0,
});
        // <:!:initialize
    }

    #[view]
    /// Return the address of the managed fungible asset that's created when this module is deployed.
    public fun get_metadata(): Object<Metadata> {
        let asset_address = object::create_object_address(&@aptos_asset, ASSET_SYMBOL);
        object::address_to_object<Metadata>(asset_address)
    }

 spec mint {
    // ✅ Only mint positive amounts
    requires amount > 0;

    // ✅ EmissionState must exist before and after
    requires exists<EmissionState>(signer::address_of(minter));
    ensures exists<EmissionState>(signer::address_of(minter));

    // ✅ Cap must not be exceeded (use pre-state directly)
    requires global<EmissionState>(signer::address_of(minter)).total_emitted + amount
        <= global<EmissionState>(signer::address_of(minter)).max_supply;

    // ✅ Total emitted increases by exactly `amount`
    ensures global<EmissionState>(signer::address_of(minter)).total_emitted
        == old(global<EmissionState>(signer::address_of(minter))).total_emitted + amount;

    // ✅ Cap remains unchanged
    ensures global<EmissionState>(signer::address_of(minter)).max_supply
        == old(global<EmissionState>(signer::address_of(minter))).max_supply;

    // ✅ Prevent rollback
    ensures global<EmissionState>(signer::address_of(minter)).total_emitted
        >= old(global<EmissionState>(signer::address_of(minter))).total_emitted;
}



    // :!:>mint
    /// Mint as the owner of metadata object.
/// Mint as the owner of metadata object.
public entry fun mint(minter: &signer, to: address, amount: u64)
    acquires ManagedFungibleAsset, EmissionState
{
    account_control::assert_not_locked(to);


    let asset = get_metadata();

    // ✅ Check: Only the metadata object owner can mint
    assert!(
        object::is_owner(asset, signer::address_of(minter)),
        error::permission_denied(ENOT_OWNER)
    );

    // ✅ Check: Emission cap not exceeded
    let emission_state = borrow_global_mut<EmissionState>(signer::address_of(minter));
    assert!(
        emission_state.total_emitted + amount <= emission_state.max_supply,
        error::permission_denied(ECAP_EXCEEDED)
    );

    // ✅ Proceed with minting
    let managed_fungible_asset = borrow_global<ManagedFungibleAsset>(object::object_address(&asset));
    let to_wallet = primary_fungible_store::ensure_primary_store_exists(to, asset);
    let fa = fungible_asset::mint(&managed_fungible_asset.mint_ref, amount);
    fungible_asset::deposit_with_ref(&managed_fungible_asset.transfer_ref, to_wallet, fa);

    // ✅ Update emission tracker
    emission_state.total_emitted = emission_state.total_emitted + amount;
}



spec transfer {
    // ✅ Only transfer positive amounts
    requires amount > 0;

    // ✅ Sender and receiver must be different
    requires from != to;

    // ✅ Emission state must exist
    requires exists<EmissionState>(signer::address_of(admin));
    ensures exists<EmissionState>(signer::address_of(admin));

    // ✅ Emission totals must not change after transfer
    ensures global<EmissionState>(signer::address_of(admin)).total_emitted
        == old(global<EmissionState>(signer::address_of(admin))).total_emitted;

    ensures global<EmissionState>(signer::address_of(admin)).max_supply
        == old(global<EmissionState>(signer::address_of(admin))).max_supply;

    // ✅ Prevent rollback (redundant here, but included for symmetry)
    ensures global<EmissionState>(signer::address_of(admin)).total_emitted
        >= old(global<EmissionState>(signer::address_of(admin))).total_emitted;

    // 🔒 Optional: Ensure neither account is locked (requires spec-viewable lock state)
    // requires !is_locked(from);
    // requires !is_locked(to);
}




    /// Transfer as the owner of metadata object ignoring `frozen` field.
    public entry fun transfer(admin: &signer, from: address, to: address, amount: u64)
    acquires ManagedFungibleAsset {
    account_control::assert_not_locked(from);
    account_control::assert_not_locked(to);

    let asset = get_metadata();
    let transfer_ref = &authorized_borrow_refs(admin, asset).transfer_ref;
    let from_wallet = primary_fungible_store::primary_store(from, asset);
    let to_wallet = primary_fungible_store::ensure_primary_store_exists(to, asset);
    fungible_asset::transfer_with_ref(transfer_ref, from_wallet, to_wallet, amount);
}


spec burn {
    // ✅ Only burn positive amounts
    requires amount > 0;

    // ✅ Emission state must exist before and after burn
    requires exists<EmissionState>(signer::address_of(admin));
    ensures exists<EmissionState>(signer::address_of(admin));

    // ✅ Total emitted must stay the same (burning doesn't roll back emissions)
    ensures global<EmissionState>(signer::address_of(admin)).total_emitted
        == old(global<EmissionState>(signer::address_of(admin))).total_emitted;

    // ✅ Cap must remain unchanged
    ensures global<EmissionState>(signer::address_of(admin)).max_supply
        == old(global<EmissionState>(signer::address_of(admin))).max_supply;

    // ✅ Optional: from must not be locked (requires ghost state or #[view] support)
    // requires !is_locked(from);
}


    /// Burn fungible assets as the owner of metadata object.
    public entry fun burn(admin: &signer, from: address, amount: u64) acquires ManagedFungibleAsset {
        account_control::assert_not_locked(from);
        let asset = get_metadata();
        let burn_ref = &authorized_borrow_refs(admin, asset).burn_ref;
        let from_wallet = primary_fungible_store::primary_store(from, asset);
        fungible_asset::burn_from(burn_ref, from_wallet, amount);
    }

spec freeze_account {
    // ✅ Emission state must remain unchanged
    requires exists<EmissionState>(signer::address_of(admin));
    ensures exists<EmissionState>(signer::address_of(admin));

    // ✅ total_emitted must remain constant
    ensures global<EmissionState>(signer::address_of(admin)).total_emitted
        == old(global<EmissionState>(signer::address_of(admin))).total_emitted;

    // ✅ Cap must not be modified by freezing
    ensures global<EmissionState>(signer::address_of(admin)).max_supply
        == old(global<EmissionState>(signer::address_of(admin))).max_supply;

    // ✅ Optional: freezing has no rollback effect
    ensures global<EmissionState>(signer::address_of(admin)).total_emitted
        >= old(global<EmissionState>(signer::address_of(admin))).total_emitted;

    // 🔒 Optional: can add an assertion that account is not already frozen
    // requires !is_frozen(account);
}

    /// Freeze an account so it cannot transfer or receive fungible assets.
    public entry fun freeze_account(admin: &signer, account: address) acquires ManagedFungibleAsset {
        let asset = get_metadata();
        let transfer_ref = &authorized_borrow_refs(admin, asset).transfer_ref;
        let wallet = primary_fungible_store::ensure_primary_store_exists(account, asset);
        fungible_asset::set_frozen_flag(transfer_ref, wallet, true);
    }


spec unfreeze_account {
    // ✅ Emission state must remain unchanged
    requires exists<EmissionState>(signer::address_of(admin));
    ensures exists<EmissionState>(signer::address_of(admin));

    // ✅ total_emitted must remain constant
    ensures global<EmissionState>(signer::address_of(admin)).total_emitted
        == old(global<EmissionState>(signer::address_of(admin))).total_emitted;

    // ✅ Cap must not be affected by unfreezing
    ensures global<EmissionState>(signer::address_of(admin)).max_supply
        == old(global<EmissionState>(signer::address_of(admin))).max_supply;

    // ✅ Optional: unfreezing must not roll back any state
    ensures global<EmissionState>(signer::address_of(admin)).total_emitted
        >= old(global<EmissionState>(signer::address_of(admin))).total_emitted;

    // 🔓 Optional: can add assertion that account is currently frozen
    // requires is_frozen(account);
}

    /// Unfreeze an account so it can transfer or receive fungible assets.
    public entry fun unfreeze_account(admin: &signer, account: address) acquires ManagedFungibleAsset {
        let asset = get_metadata();
        let transfer_ref = &authorized_borrow_refs(admin, asset).transfer_ref;
        let wallet = primary_fungible_store::ensure_primary_store_exists(account, asset);
        fungible_asset::set_frozen_flag(transfer_ref, wallet, false);
    }

    spec withdraw {
    // ✅ Must withdraw a positive amount
    requires amount > 0;

    // ✅ Emission state must remain unchanged
    requires exists<EmissionState>(signer::address_of(admin));
    ensures exists<EmissionState>(signer::address_of(admin));

    // ✅ Total emitted must remain the same
    ensures global<EmissionState>(signer::address_of(admin)).total_emitted
        == old(global<EmissionState>(signer::address_of(admin))).total_emitted;

    // ✅ Cap must remain unchanged
    ensures global<EmissionState>(signer::address_of(admin)).max_supply
        == old(global<EmissionState>(signer::address_of(admin))).max_supply;

    // ✅ Optional: account must not be locked (requires ghost state or #[view])
    // requires !is_locked(from);

    // ✅ Optional: result must be a fungible asset with the correct amount
    // ensures result.amount == amount;
}


    /// Withdraw as the owner of metadata object ignoring `frozen` field.
    public fun withdraw(admin: &signer, amount: u64, from: address): FungibleAsset acquires ManagedFungibleAsset {
         account_control::assert_not_locked(from);
        let asset = get_metadata();
        let transfer_ref = &authorized_borrow_refs(admin, asset).transfer_ref;
        let from_wallet = primary_fungible_store::primary_store(from, asset);
        fungible_asset::withdraw_with_ref(transfer_ref, from_wallet, amount)
    }


    spec deposit {
    // ✅ Emission state must remain unchanged
    requires exists<EmissionState>(signer::address_of(admin));
    ensures exists<EmissionState>(signer::address_of(admin));

    // ✅ Total emitted must remain the same
    ensures global<EmissionState>(signer::address_of(admin)).total_emitted
        == old(global<EmissionState>(signer::address_of(admin))).total_emitted;

    // ✅ Cap must remain unchanged
    ensures global<EmissionState>(signer::address_of(admin)).max_supply
        == old(global<EmissionState>(signer::address_of(admin))).max_supply;

    // ✅ Optional: account must not be locked (requires ghost state or #[view])
    // requires !is_locked(to);

    // ✅ Optional: deposited amount should be non-zero (depends on fa.value if visible)
    // requires fa.value > 0;
}


    /// Deposit as the owner of metadata object ignoring `frozen` field.
    public fun deposit(admin: &signer, to: address, fa: FungibleAsset) acquires ManagedFungibleAsset {
            account_control::assert_not_locked(to);
        let asset = get_metadata();
        let transfer_ref = &authorized_borrow_refs(admin, asset).transfer_ref;
        let to_wallet = primary_fungible_store::ensure_primary_store_exists(to, asset);
        fungible_asset::deposit_with_ref(transfer_ref, to_wallet, fa);
    }
    

    spec set_max_supply {
    // ✅ Emission state must exist before and after
    requires exists<EmissionState>(signer::address_of(admin));
    ensures exists<EmissionState>(signer::address_of(admin));

    // ✅ Cap must not be set below already emitted amount
    requires new_cap >= global<EmissionState>(signer::address_of(admin)).total_emitted;

    // ✅ Cap must equal the new_cap provided
    ensures global<EmissionState>(signer::address_of(admin)).max_supply == new_cap;

    // ✅ Emitted total must remain unchanged
    ensures global<EmissionState>(signer::address_of(admin)).total_emitted
        == old(global<EmissionState>(signer::address_of(admin))).total_emitted;
}


    /// Admin sets or updates the maximum supply cap.
public entry fun set_max_supply(admin: &signer, new_cap: u64) acquires EmissionState {
    let emission = borrow_global_mut<EmissionState>(signer::address_of(admin));
    
    assert!(
        new_cap >= emission.total_emitted,
        error::permission_denied(ECAP_LOWER_THAN_EMITTED)
    );

    emission.max_supply = new_cap;
}


spec get_emission_state {
    // Just ensuring emission state exists for the address
    requires exists<EmissionState>(admin_address);
    ensures result_1 == global<EmissionState>(admin_address).total_emitted;
    ensures result_2 == global<EmissionState>(admin_address).max_supply;
}


public fun get_emission_state(admin_address: address): (u64, u64) acquires EmissionState {
    let emission = borrow_global<EmissionState>(admin_address);
    (emission.total_emitted, emission.max_supply)
}





public entry fun grant_mint_capability(admin: &signer, recipient: &signer)  {
    let asset = get_metadata();
    assert!(object::is_owner(asset, signer::address_of(admin)), error::permission_denied(ENOT_OWNER));

    move_to(recipient, MintCapability {});
}

spec revoke_mint_capability {
    // ✅ Capability must exist at the target
    requires exists<MintCapability>(target);
    ensures !exists<MintCapability>(target);
}

public entry fun revoke_mint_capability(_admin: &signer, target: address) acquires MintCapability {
    let cap = move_from<MintCapability>(target);
    destroy_mint_capability(cap);
}


fun destroy_mint_capability(cap: MintCapability) {
    let MintCapability {} = cap;
}



public entry fun grant_burn_capability(admin: &signer, recipient: &signer){
    let asset = get_metadata();
    assert!(object::is_owner(asset, signer::address_of(admin)), error::permission_denied(ENOT_OWNER));
    move_to(recipient, BurnCapability{})
}


public entry fun revoke_burn_capability(_admin: &signer, target:address) acquires BurnCapability{
    let cap = move_from<BurnCapability>(target);
    destroy_burn_capability(cap);
}

fun destroy_burn_capability(cap: BurnCapability){
    let BurnCapability {} = cap;
}

public entry fun grant_freeze_capability(admin: &signer, reciepient: &signer){
    let asset = get_metadata();
    assert!(object::is_owner(asset, signer::address_of(admin)), error::permission_denied(ENOT_OWNER));
    move_to(reciepient, FreezeCapability{})
}


public entry fun revoke_freeze_capability(_admin: &signer, target:address) acquires FreezeCapability{
    let cap = move_from<FreezeCapability>(target);
    destroy_freeze_capability(cap);
}

fun destroy_freeze_capability(cap: FreezeCapability){
    let FreezeCapability {} = cap;
}

public entry fun grant_unfreeze_capability(admin: &signer, reciepient: &signer){
    let asset = get_metadata();
    assert!(object::is_owner(asset, signer::address_of(admin)), error::permission_denied(ENOT_OWNER));
    move_to(reciepient,UnfreezeCapability)
}


public entry fun revoke_unfreeze_capability(_admin: &signer, target:address) acquires UnfreezeCapability{
    let cap = move_from<UnfreezeCapability>(target);
    destroy_unfreeze_capability(cap);
}
fun destroy_unfreeze_capability(cap: UnfreezeCapability){
    let UnfreezeCapability {} = cap;
}


public entry fun grant_withdraw_capability(admin: &signer, recipient: &signer) {
    let asset = get_metadata();
    assert!(object::is_owner(asset, signer::address_of(admin)), error::permission_denied(ENOT_OWNER));
    move_to(recipient, WithdrawCapability {});
}

public entry fun revoke_withdraw_capability(admin: &signer, target: address) acquires WithdrawCapability {
    let asset = get_metadata();
    assert!(object::is_owner(asset, signer::address_of(admin)), error::permission_denied(ENOT_OWNER));
    let cap = move_from<WithdrawCapability>(target);
    destroy_withdraw_capability(cap);
}

fun destroy_withdraw_capability(cap: WithdrawCapability) {
    let WithdrawCapability {} = cap;
}


public entry fun grant_deposit_capability(admin: &signer, reciepient: &signer){
    let asset = get_metadata();
    assert!(object::is_owner(asset,signer::address_of(admin)), error::permission_denied(ENOT_OWNER));
    move_to(reciepient,DepositCapability{});
}
public entry fun revoke_deposit_capability(admin: &signer, target: address)acquires DepositCapability{
    let asset = get_metadata();
    assert!(object::is_owner(asset, signer::address_of(admin)), error::permission_denied(ENOT_OWNER));
    let cap =move_from<DepositCapability>(target);
    destroy_deposit_capability(cap);
}

fun destroy_deposit_capability(cap: DepositCapability){
    let DepositCapability {} = cap;
}
    /// Borrow the immutable reference of the refs of `metadata`.
    /// This validates that the signer is the metadata object's owner.
    inline fun authorized_borrow_refs(
        owner: &signer,
        asset: Object<Metadata>,
    ): &ManagedFungibleAsset acquires ManagedFungibleAsset {
        assert!(object::is_owner(asset, signer::address_of(owner)), error::permission_denied(ENOT_OWNER));
        borrow_global<ManagedFungibleAsset>(object::object_address(&asset))
    }

// In your main module

public fun test_initialize(admin: &signer) {
    let constructor_ref = &object::create_named_object(admin, ASSET_SYMBOL);
    primary_fungible_store::create_primary_store_enabled_fungible_asset(
        constructor_ref,
        option::none(),
        utf8(b"BLOCKFORGE Coin"),
        utf8(ASSET_SYMBOL),
        8,
        utf8(b"https://..."),
        utf8(b"http://metaschool.so"),
    );

    let mint_ref = fungible_asset::generate_mint_ref(constructor_ref);
    let burn_ref = fungible_asset::generate_burn_ref(constructor_ref);
    let transfer_ref = fungible_asset::generate_transfer_ref(constructor_ref);
    let metadata_object_signer = object::generate_signer(constructor_ref);
    move_to(
        &metadata_object_signer,
        ManagedFungibleAsset { mint_ref, transfer_ref, burn_ref }
    );
    move_to(admin, EmissionState {
        max_supply: 0,
        total_emitted: 0,
    });
}

/// --- Add this at the bottom of your module ---

#[test_only]
public fun test_mint_flow(admin: &signer, user: address, amount: u64) acquires ManagedFungibleAsset, EmissionState {
    init_module(admin);
    set_max_supply(admin, 1000);
    mint(admin, user, amount);
}

#[test_only]
public fun get_metadata_for_test(): object::Object<Metadata> {
    get_metadata()
}

#[test_only]
public entry fun test_init_module(admin: &signer) {
    init_module(admin);
}



}





// | Aspect                    | Status     |
// | ------------------------- | ---------- |
// | Logical correctness       | ✅ Strong   |
// | Code-level enforceability | ✅ Strong   |
// | Readability               | ✅ Strong   |
// | Formal verification ready | ✅ Good     |
// | Security logic            | ✅ Good     |
// | Ghost-state/invariants    | ❌ Missing  |
// | Audit-grade completeness  | 🔶 Partial |
// | Advanced resource model   | 🔶 Partial |


//// | Aspect                    | Status     |
// | ------------------------- | ---------- |
// | Logical correctness       | ✅ Strong   |
// | Code-level enforceability | ✅ Strong   |
// | Readability               | ✅ Strong   |
// | Formal verification ready | ✅ Good     |
// | Security logic            | ✅ Good     |
// | Ghost-state/invariants    | ❌ Missing  |
// | Audit-grade completeness  | 🔶 Partial |
// | Advanced resource model   | 🔶 Partial |