// module tests::fungible_asset_test {
//     use aptos_framework::object;
//     use aptos_framework::fungible_asset::Metadata;
//     use aptos_framework::primary_fungible_store;

//     use aptos_asset::fungible_asset::{
//         self, ManagedFungibleAsset, EmissionState
//     };

//     use std::signer;
//     use std::option;

//     #[test_only]
//     public fun get_metadata_for_test(): object::Object<Metadata> {
//         fungible_asset::get_metadata()
//     }

//     #[test(admin = @0xCAFE)]
//     public fun test_mint_basic(admin: &signer) {
//         // Step 1: Simulate init_module logic
//         let constructor_ref = &object::create_named_object(admin, b"BFC");

//         primary_fungible_store::create_primary_store_enabled_fungible_asset(
//             constructor_ref,
//             option::none(),
//             b"BLOCKFORGE Coin", // name
//             b"BFC",             // symbol
//             8,                  // decimals
//             b"https://drive.google.com/file/d/1vFm-kF6O3onxPgFJ_rVLh9YGFT_fFWM6/view?usp=sharing", // icon
//             b"http://metaschool.so" // project
//         );

//         let mint_ref = fungible_asset::generate_mint_ref(constructor_ref);
//         let burn_ref = fungible_asset::generate_burn_ref(constructor_ref);
//         let transfer_ref = fungible_asset::generate_transfer_ref(constructor_ref);

//         let metadata_object_signer = object::generate_signer(constructor_ref);

//         move_to(
//             &metadata_object_signer,
//             ManagedFungibleAsset { mint_ref, transfer_ref, burn_ref }
//         );

//         move_to(admin, EmissionState {
//             max_supply: 0,
//             total_emitted: 0,
//         });

//         // Step 2: Set emission cap
//         fungible_asset::set_max_supply(admin, 1_000);

//         // Step 3: Mint tokens
//         fungible_asset::mint(admin, @0xBEEF, 250);

//         // Step 4: Check updated state
//         let (total_emitted, max_supply) = fungible_asset::get_emission_state(signer::address_of(admin));
//         assert!(total_emitted == 250, 0x01);
//         assert!(max_supply == 1_000, 0x02);
//     }
// }
