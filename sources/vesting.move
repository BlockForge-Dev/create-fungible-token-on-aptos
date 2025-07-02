// module aptos_asset::vesting {
//     use aptos_framework::event;
//     use std::error;
//     use std::signer;
//     use std::option;
//     use aptos_asset::fungible_asset::{Self, FungibleAsset, Metadata};
//     use aptos_asset::account_control;

//     // ========== Data Structures ==========

//     /// Vesting schedule configuration
//     struct VestingSchedule has store {
//         start_time: u64,      // Unix timestamp
//         cliff_duration: u64,  // Seconds until cliff
//         duration: u64,        // Total vesting duration (seconds)
//         total_amount: u64,    // Total tokens to vest
//         released: u64         // Amount already claimed
//     }

//     /// Vesting wallet state
//     struct VestingWallet has key {
//         beneficiary: address,
//         schedules: vector<VestingSchedule>,
//         admin_cap: VestingAdminCap
//     }

//     /// Admin capability for vesting management
//     struct VestingAdminCap has key {}

//     // ========== Events ==========

//     /// Emitted when new vesting schedule is created
//     struct VestingScheduleCreated has drop, store {
//         wallet: address,
//         beneficiary: address,
//         total_amount: u64,
//         start_time: u64,
//         duration: u64
//     }

//     /// Emitted when tokens are released
//     struct TokensReleased has drop, store {
//         wallet: address,
//         beneficiary: address,
//         amount: u64
//     }

//     // ========== Constants ==========

//     const ENOT_ADMIN: u64 = 4000;
//     const ENOT_BENEFICIARY: u64 = 4001;
//     const ENOTHING_TO_CLAIM: u64 = 4002;
//     const EINVALID_SCHEDULE: u64 = 4003;
//     const EVESTING_LOCKED: u64 = 4004;

//     // ========== Initialization ==========

//     /// Create a new vesting wallet
//     public entry fun create_vesting_wallet(
//         admin: &signer,
//         token: Object<Metadata>,
//         beneficiary: address,
//         start_time: u64,
//         cliff_duration: u64,
//         vesting_duration: u64,
//         total_amount: u64
//     ) {
//         assert!(
//             object::is_owner(token, signer::address_of(admin)),
//             error::permission_denied(ENOT_ADMIN)
//         );
//         assert!(vesting_duration > 0, error::invalid_argument(EINVALID_SCHEDULE));
//         assert!(total_amount > 0, error::invalid_argument(EINVALID_SCHEDULE));

//         let wallet_address = signer::address_of(admin);
//         let schedules = vector::empty();
//         vector::push_back(&mut schedules, VestingSchedule {
//             start_time,
//             cliff_duration,
//             duration: vesting_duration,
//             total_amount,
//             released: 0
//         });

//         move_to(
//             admin,
//             VestingWallet {
//                 beneficiary,
//                 schedules,
//                 admin_cap: VestingAdminCap {}
//             }
//         );

//         event::emit(VestingScheduleCreated {
//             wallet: wallet_address,
//             beneficiary,
//             total_amount,
//             start_time,
//             duration: vesting_duration
//         });
//     }

//     // ========== Core Functions ==========

//     /// Release vested tokens to beneficiary
//     public entry fun release(
//         beneficiary: &signer,
//         token: Object<Metadata>
//     ) acquires VestingWallet {
//         let beneficiary_addr = signer::address_of(beneficiary);
//         let wallet = borrow_global_mut<VestingWallet>(get_wallet_for_beneficiary(beneficiary_addr));
        
//         account_control::assert_not_locked(wallet.beneficiary);
//         assert!(
//             beneficiary_addr == wallet.beneficiary,
//             error::permission_denied(ENOT_BENEFICIARY)
//         );

//         let releasable = calculate_releasable_amount(wallet);
//         assert!(releasable > 0, error::invalid_state(ENOTHING_TO_CLAIM));

//         let managed_fa = fungible_asset::authorized_borrow_refs(beneficiary, token);
//         let to_wallet = primary_fungible_store::ensure_primary_store_exists(beneficiary_addr, token);
//         let fa = fungible_asset::withdraw_with_ref(
//             &managed_fa.transfer_ref,
//             object::address_to_object(to_wallet),
//             releasable
//         );
//         fungible_asset::deposit_with_ref(&managed_fa.transfer_ref, to_wallet, fa);

//         // Update released amount
//         let schedule = vector::borrow_mut(&mut wallet.schedules, 0);
//         schedule.released = schedule.released + releasable;

//         event::emit(TokensReleased {
//             wallet: object::address_to_object(token),
//             beneficiary: beneficiary_addr,
//             amount: releasable
//         });
//     }

//     // ========== Admin Functions ==========

//     /// Add new vesting schedule (for multi-tranche vesting)
//     public entry fun add_vesting_schedule(
//         admin: &signer,
//         beneficiary: address,
//         start_time: u64,
//         cliff_duration: u64,
//         vesting_duration: u64,
//         total_amount: u64
//     ) acquires VestingWallet {
//         authenticate_admin(admin, beneficiary);
//         assert!(vesting_duration > 0, error::invalid_argument(EINVALID_SCHEDULE));
//         assert!(total_amount > 0, error::invalid_argument(EINVALID_SCHEDULE));

//         let wallet = borrow_global_mut<VestingWallet>(get_wallet_for_beneficiary(beneficiary));
//         vector::push_back(&mut wallet.schedules, VestingSchedule {
//             start_time,
//             cliff_duration,
//             duration: vesting_duration,
//             total_amount,
//             released: 0
//         });

//         event::emit(VestingScheduleCreated {
//             wallet: signer::address_of(admin),
//             beneficiary,
//             total_amount,
//             start_time,
//             duration: vesting_duration
//         });
//     }

//     // ========== View Functions ==========

//     /// Calculate currently releasable amount
//     public fun calculate_releasable_amount(
//         wallet: &VestingWallet
//     ): u64 {
//         let current_time = timestamp::now_seconds();
//         let total_releasable = 0;
//         let total_released = 0;

//         let i = 0;
//         while (i < vector::length(&wallet.schedules)) {
//             let schedule = vector::borrow(&wallet.schedules, i);
//             total_released = total_released + schedule.released;

//             if (current_time < schedule.start_time + schedule.cliff_duration) {
//                 i = i + 1;
//                 continue;
//             };

//             let vested = if (current_time >= schedule.start_time + schedule.duration) {
//                 schedule.total_amount
//             } else {
//                 schedule.total_amount * (current_time - schedule.start_time) / schedule.duration
//             };

//             total_releasable = total_releasable + (vested - schedule.released);
//             i = i + 1;
//         };

//         total_releasable
//     }

//     // ========== Private Helpers ==========

//     fun get_wallet_for_beneficiary(beneficiary: address): address {
//         // Implementation depends on your wallet lookup logic
//         // Could use resource account or other mapping
//         beneficiary
//     }

//     fun authenticate_admin(admin: &signer, beneficiary: address) {
//         let wallet = borrow_global<VestingWallet>(get_wallet_for_beneficiary(beneficiary));
//         assert!(
//             signer::address_of(admin) == object::address_to_object(wallet.admin_cap),
//             error::permission_denied(ENOT_ADMIN)
//         );
//     }
// }