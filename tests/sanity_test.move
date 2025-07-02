module tests::sanity_test {
    use std::debug;

    #[test]
    public entry fun test_sanity() {
        debug::print(&b"Hello from test");
    }


    
}
