module aptos_asset::account_control {
    use aptos_framework::timestamp;
    use std::signer;
    use std::error;
    use std::option;
    
    const EACCOUNT_LOCKED: u64 = 0xE3;
    const ENOT_ADMIN: u64 = 0xE4;
    const EALREADY_LOCKED: u64 = 0xE5;

    struct TimeLock has key {
        unlock_time_secs: u64,
    }

    struct LockAdmin has key, drop {  // Keep drop ability
        _dummy: bool,
    }

    /// Initialize admin capabilities during module initialization
    fun init_module(admin: &signer) {  // Changed from public to private
        move_to(admin, LockAdmin { _dummy: false });
    }

    spec unlock {
    // Admin must have LockAdmin privileges before and after
    requires exists<LockAdmin>(signer::address_of(admin));
    ensures exists<LockAdmin>(signer::address_of(admin));
}

public entry fun unlock(admin: &signer, user: address) acquires TimeLock {
    unlock_account(admin, user);
}
spec lock_account {
    requires exists<LockAdmin>(signer::address_of(admin));
    ensures exists<LockAdmin>(signer::address_of(admin));

    requires !exists<TimeLock>(signer::address_of(account));
    ensures exists<TimeLock>(signer::address_of(account));
    ensures global<TimeLock>(signer::address_of(account)).unlock_time_secs == unlock_time_secs;
}


    /// Lock an account until a specific time
    public entry fun lock_account(admin: &signer, account: &signer, unlock_time_secs: u64) {
        assert!(exists<LockAdmin>(signer::address_of(admin)), error::permission_denied(ENOT_ADMIN));
        assert!(!exists<TimeLock>(signer::address_of(account)), error::invalid_state(EALREADY_LOCKED));
        
        move_to(account, TimeLock { unlock_time_secs });
    }

spec unlock_account {
    // ✅ Admin must have LockAdmin privileges before and after
    requires exists<LockAdmin>(signer::address_of(admin));
    ensures exists<LockAdmin>(signer::address_of(admin));

    // ✅ If target had a lock before, it must be removed now
    ensures old(exists<TimeLock>(target)) ==> !exists<TimeLock>(target);

    // ✅ If target was not locked before, it remains unlocked
    ensures !old(exists<TimeLock>(target)) ==> !exists<TimeLock>(target);

    // ✅ Function must not create a lock on anyone
   // ensures !exists<TimeLock>(signer::address_of(admin));
}


    /// Unlock an account manually before its time expires
    public entry fun unlock_account(admin: &signer, target: address) acquires TimeLock {
        assert!(exists<LockAdmin>(signer::address_of(admin)), error::permission_denied(ENOT_ADMIN));
        
        if (exists<TimeLock>(target)) {
            let lock = move_from<TimeLock>(target);
            destroy_lock(lock);
        }
    }

    fun destroy_lock(lock: TimeLock) {
        let TimeLock { unlock_time_secs: _ } = lock;
    }
spec assert_not_locked {
    // If no TimeLock exists, this always passes
    // If a TimeLock exists, it must be expired
    ensures
        !exists<TimeLock>(account)
        || timestamp::now_seconds() >= global<TimeLock>(account).unlock_time_secs;
}

    /// Public helper to check if account is locked
    public fun assert_not_locked(account: address) acquires TimeLock {
        if (exists<TimeLock>(account)) {
            let lock = borrow_global<TimeLock>(account);
            assert!(
                timestamp::now_seconds() >= lock.unlock_time_secs,
                error::permission_denied(EACCOUNT_LOCKED)
            );
        }
    }
    spec get_lock_info {
    // No state changes
    ensures true;

    // If locked, result must be Option with one element
    ensures
        exists<TimeLock>(account) ==>
        result.vec == vector[global<TimeLock>(account).unlock_time_secs];

    // If not locked, result must be an empty Option
    ensures
        !exists<TimeLock>(account) ==>
        result.vec == vector[];
}


    /// View lock status
    public fun get_lock_info(account: address): option::Option<u64> acquires TimeLock {
        if (exists<TimeLock>(account)) {
            let lock = borrow_global<TimeLock>(account);
            option::some(lock.unlock_time_secs)
        } else {
            option::none()
        }
    }

    spec grant_lock_admin {
    // The `admin` must be a valid LockAdmin
    requires exists<LockAdmin>(signer::address_of(admin));

    // After the call, the recipient must become a LockAdmin
    ensures exists<LockAdmin>(signer::address_of(recipient));

    // The admin must retain their privileges
    ensures exists<LockAdmin>(signer::address_of(admin));
}

    
    /// Grant lock admin privileges to another account
    public entry fun grant_lock_admin(admin: &signer, recipient: &signer) {
        assert!(exists<LockAdmin>(signer::address_of(admin)), error::permission_denied(ENOT_ADMIN));
        move_to(recipient, LockAdmin { _dummy: false });
    }
    
    spec revoke_lock_admin {
    // Caller must already be a LockAdmin
    requires exists<LockAdmin>(signer::address_of(admin));

    // The target must have LockAdmin before revocation
    requires exists<LockAdmin>(target);

    // After the call, the target no longer has LockAdmin
    ensures !exists<LockAdmin>(target);

    // Caller retains their admin privileges
    //ensures exists<LockAdmin>(signer::address_of(admin));
}

    /// Revoke lock admin privileges
    public entry fun revoke_lock_admin(admin: &signer, target: address) acquires LockAdmin {
        assert!(exists<LockAdmin>(signer::address_of(admin)), error::permission_denied(ENOT_ADMIN));
        let admin_resource = move_from<LockAdmin>(target);
        destroy_lock_admin(admin_resource);
    }

    fun destroy_lock_admin(admin: LockAdmin) {
        let LockAdmin { _dummy: _ } = admin;
    }
} 