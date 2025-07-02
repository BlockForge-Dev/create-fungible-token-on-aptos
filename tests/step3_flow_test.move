// module tests::step3_flow_test {
//     use aptos_framework::aptos_account;
//     use aptos_asset::fungible_asset;

//     #[test]
//     fun mint_flow() {
//         let admin = @0xA;
//         let user = @0xB;

//         let admin_signer = aptos_account::create_signer(admin);
//         let user_signer = aptos_account::create_signer(user);

//         fungible_asset::init_module(&admin_signer);
//         fungible_asset::set_max_supply(&admin_signer, 1_000);
//         fungible_asset::mint(&admin_signer, user, 500);
//         fungible_asset::withdraw(&admin_signer, 300, user);
//     }
// }
