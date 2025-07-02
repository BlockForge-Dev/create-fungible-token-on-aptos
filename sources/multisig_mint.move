// module aptos_asset::multisig_mint {
//     use aptos_framework::event;
//     use std::error;
//     use std::signer;
//     use std::vector;
//     use aptos_asset::fungible_asset::{Self, Metadata, FungibleAsset};
//     use aptos_asset::account_control;

//     // ========== Data Structures ==========

//     /// Configuration for a multi-signature minting group
//     struct MintGroup has key {
//         signers: vector<address>,
//         threshold: u64,
//         next_proposal_id: u64,
//         token: Object<Metadata>
//     }

//     /// Pending mint proposal requiring approvals
//     struct MintProposal has key {
//         id: u64,
//         to: address,
//         amount: u64,
//         approvals: vector<address>,
//         executed: bool
//     }

//     /// Event emitted when new proposal created
//     struct ProposalCreatedEvent has drop, store {
//         proposal_id: u64,
//         creator: address,
//         to: address,
//         amount: u64
//     }

//     /// Event emitted when proposal executed
//     struct ProposalExecutedEvent has drop, store {
//         proposal_id: u64,
//         executor: address
//     }

//     // ========== Constants ==========

//     const EMIN_THRESHOLD: u64 = 3000;
//     const EINVALID_PROPOSAL: u64 = 3001;
//     const ENOT_SIGNER: u64 = 3002;
//     const EALREADY_APPROVED: u64 = 3003;
//     const ETHRESHOLD_NOT_MET: u64 = 3004;

//     // ========== Initialization ==========

//     /// Create a new minting group
//     public entry fun create_mint_group(
//         admin: &signer,
//         token: Object<Metadata>,
//         initial_signers: vector<address>,
//         threshold: u64
//     ) {
//         assert!(
//             object::is_owner(token, signer::address_of(admin)),
//             error::permission_denied(account_control::ENOT_ADMIN)
//         );
//         assert!(
//             threshold <= vector::length(&initial_signers) && threshold > 0,
//             error::invalid_argument(EMIN_THRESHOLD)
//         );

//         move_to(
//             admin,
//             MintGroup {
//                 signers: initial_signers,
//                 threshold,
//                 next_proposal_id: 0,
//                 token
//             }
//         );
//     }

//     // ========== Proposal Lifecycle ==========

//     /// Create a new mint proposal
//     public entry fun create_proposal(
//         creator: &signer,
//         to: address,
//         amount: u64
//     ) acquires MintGroup {
//         let creator_addr = signer::address_of(creator);
//         let mint_group = borrow_global_mut<MintGroup>(creator_addr);
//         assert!(
//             vector::contains(&mint_group.signers, &creator_addr),
//             error::permission_denied(ENOT_SIGNER)
//         );

//         let proposal_id = mint_group.next_proposal_id;
//         mint_group.next_proposal_id = proposal_id + 1;

//         let approvals = vector::empty();
//         vector::push_back(&mut approvals, creator_addr);

//         move_to(
//             creator,
//             MintProposal {
//                 id: proposal_id,
//                 to,
//                 amount,
//                 approvals,
//                 executed: false
//             }
//         );

//         event::emit(ProposalCreatedEvent {
//             proposal_id,
//             creator: creator_addr,
//             to,
//             amount
//         });
//     }

//     /// Approve a pending mint proposal
//     public entry fun approve_proposal(
//         approver: &signer,
//         proposal_creator: address,
//         proposal_id: u64
//     ) acquires MintGroup, MintProposal {
//         let approver_addr = signer::address_of(approver);
//         let mint_group = borrow_global<MintGroup>(proposal_creator);
//         assert!(
//             vector::contains(&mint_group.signers, &approver_addr),
//             error::permission_denied(ENOT_SIGNER)
//         );

//         let proposal = borrow_global_mut<MintProposal>(proposal_creator);
//         assert!(proposal.id == proposal_id, error::invalid_argument(EINVALID_PROPOSAL));
//         assert!(!proposal.executed, error::invalid_state(EINVALID_PROPOSAL));
//         assert!(
//             !vector::contains(&proposal.approvals, &approver_addr),
//             error::invalid_state(EALREADY_APPROVED)
//         );

//         vector::push_back(&mut proposal.approvals, approver_addr);
//     }

//     /// Execute approved mint proposal
//     public entry fun execute_proposal(
//         executor: &signer,
//         proposal_creator: address,
//         proposal_id: u64
//     ) acquires MintGroup, MintProposal {
//         let executor_addr = signer::address_of(executor);
//         let mint_group = borrow_global<MintGroup>(proposal_creator);
//         assert!(
//             vector::contains(&mint_group.signers, &executor_addr),
//             error::permission_denied(ENOT_SIGNER)
//         );

//         let proposal = borrow_global_mut<MintProposal>(proposal_creator);
//         assert!(proposal.id == proposal_id, error::invalid_argument(EINVALID_PROPOSAL));
//         assert!(!proposal.executed, error::invalid_state(EINVALID_PROPOSAL));
//         assert!(
//             vector::length(&proposal.approvals) >= mint_group.threshold,
//             error::permission_denied(ETHRESHOLD_NOT_MET)
//         );

//         // Perform the mint
//         let managed_fa = fungible_asset::authorized_borrow_refs(executor, mint_group.token);
//         let to_wallet = primary_fungible_store::ensure_primary_store_exists(proposal.to, mint_group.token);
//         let fa = fungible_asset::mint(&managed_fa.mint_ref, proposal.amount);
//         fungible_asset::deposit_with_ref(&managed_fa.transfer_ref, to_wallet, fa);

//         proposal.executed = true;
//         event::emit(ProposalExecutedEvent { proposal_id, executor: executor_addr });
//     }

//     // ========== View Functions ==========

//     /// Check if proposal is executable
//     public fun is_proposal_executable(
//         proposal_creator: address,
//         proposal_id: u64
//     ): bool acquires MintGroup, MintProposal {
//         if (!exists<MintProposal>(proposal_creator)) return false;
        
//         let mint_group = borrow_global<MintGroup>(proposal_creator);
//         let proposal = borrow_global<MintProposal>(proposal_creator);
        
//         proposal.id == proposal_id &&
//         !proposal.executed &&
//         vector::length(&proposal.approvals) >= mint_group.threshold
//     }
// }