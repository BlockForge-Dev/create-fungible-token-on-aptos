// module aptos_asset::restriction_manager {
//     use aptos_framework::object;
//     use std::error;
//     use std::signer;
//     use std::vector;
//     use aptos_asset::fungible_asset::Metadata;
//     use aptos_asset::account_control;

//     /// Role capability for managing restrictions
//     struct RestrictionAdminCap has key {}

//     /// Storage for restricted addresses
//     struct AddressRestrictions has key {
//         whitelist: vector<address>,
//         blacklist: vector<address>,
//         // Tracks if whitelist is active (false = blacklist mode)
//         whitelist_enabled: bool 
//     }

//     /// Error codes
//     const ENOT_ADMIN: u64 = 2000;
//     const EADDRESS_ALREADY_LISTED: u64 = 2001;
//     const EADDRESS_NOT_LISTED: u64 = 2002;
//     const ERESTRICTION_VIOLATION: u64 = 2003;

//     // ========== Initialization ==========

//     /// Initialize restriction system for a token
//     public entry fun initialize(
//         admin: &signer,
//         token: Object<Metadata>
//     ) {
//         assert!(
//             object::is_owner(token, signer::address_of(admin)),
//             error::permission_denied(ENOT_ADMIN)
//         );

//         move_to(
//             admin,
//             AddressRestrictions {
//                 whitelist: vector::empty(),
//                 blacklist: vector::empty(),
//                 whitelist_enabled: false // Default to blacklist mode
//             }
//         );

//         // Grant admin capability
//         move_to(admin, RestrictionAdminCap {});
//     }

//     // ========== Admin Functions ==========

//     /// Add address to whitelist
//     public entry fun add_to_whitelist(
//         admin: &signer,
//         token: Object<Metadata>,
//         addr: address
//     ) acquires AddressRestrictions {
//         authenticate(admin, token);
//         let restrictions = borrow_global_mut<AddressRestrictions>(object::object_address(&token));
//         assert!(
//             !vector::contains(&restrictions.whitelist, &addr),
//             error::already_exists(EADDRESS_ALREADY_LISTED)
//         );
//         vector::push_back(&mut restrictions.whitelist, addr);
//     }

//     /// Remove address from whitelist
//     public entry fun remove_from_whitelist(
//         admin: &signer,
//         token: Object<Metadata>,
//         addr: address
//     ) acquires AddressRestrictions {
//         authenticate(admin, token);
//         let restrictions = borrow_global_mut<AddressRestrictions>(object::object_address(&token));
//         let (contains, index) = vector::index_of(&restrictions.whitelist, &addr);
//         assert!(contains, error::not_found(EADDRESS_NOT_LISTED));
//         vector::remove(&mut restrictions.whitelist, index);
//     }

//     /// Toggle between whitelist/blacklist mode
//     public entry fun set_restriction_mode(
//         admin: &signer,
//         token: Object<Metadata>,
//         use_whitelist: bool
//     ) acquires AddressRestrictions {
//         authenticate(admin, token);
//         let restrictions = borrow_global_mut<AddressRestrictions>(object::object_address(&token));
//         restrictions.whitelist_enabled = use_whitelist;
//     }

//     // ========== Verification ==========

//     /// Check if transfer is allowed
//     public fun validate_transfer(
//         token: Object<Metadata>,
//         from: address,
//         to: address
//     ): bool acquires AddressRestrictions {
//         if (!exists<AddressRestrictions>(object::object_address(&token))) {
//             return true // No restrictions configured
//         };

//         let restrictions = borrow_global<AddressRestrictions>(object::object_address(&token));

//         // Check both sender and recipient
//         if (restrictions.whitelist_enabled) {
//             // Whitelist mode - both must be whitelisted
//             vector::contains(&restrictions.whitelist, &from) &&
//             vector::contains(&restrictions.whitelist, &to)
//         } else {
//             // Blacklist mode - neither can be blacklisted
//             !vector::contains(&restrictions.blacklist, &from) &&
//             !vector::contains(&restrictions.blacklist, &to)
//         }
//     }

//     // ========== Integration Helpers ==========

//     /// Call this before transfers in your fungible_asset module
//     public fun assert_transfer_allowed(
//         token: Object<Metadata>,
//         from: address,
//         to: address
//     ) acquires AddressRestrictions {
//         assert!(
//             validate_transfer(token, from, to),
//             error::permission_denied(ERESTRICTION_VIOLATION)
//         );
//     }

//     // ========== Private Helpers ==========

//     fun authenticate(admin: &signer, token: Object<Metadata>) {
//         assert!(
//             exists<RestrictionAdminCap>(signer::address_of(admin)) &&
//             object::is_owner(token, signer::address_of(admin)),
//             error::permission_denied(ENOT_ADMIN)
//         );
//     }
// }