// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.4;

import {Test} from "forge-std/Test.sol";

import {IFactory} from "../factory/IFactory.sol";
import {IUniversalVault} from "../crucible/interfaces/IUniversalVault.sol";
import {ICrucible} from "../crucible/interfaces/ICrucible.sol";
import {CrucibleFactoryV2} from "../crucible/CrucibleFactoryV2.sol";

import {BaseCrucible} from "../crucible/BaseCrucible.sol";
import {Crucible} from "../crucible/templates/Crucible.sol";
import {MockCrucibleA} from "./mocks/MockCrucibleA.sol";
import {MockCrucibleB} from "./mocks/MockCrucibleB.sol";
import {MockCrucibleC} from "./mocks/MockCrucibleC.sol";

import {VersionProxy} from "../proxy/VersionProxy.sol";
import {VersionBeacon, IVersionBeacon} from "../proxy/VersionBeacon.sol";
import {VersionTemplate} from "../proxy/VersionTemplate.sol";

import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";

import {Utils} from "./Utils.sol";

import "forge-std/console2.sol";

contract VersionProxyTest is Test {
    uint248 public constant PRIVATE_KEY = type(uint248).max >> 7;

    MockERC20 stakingToken;
    MockERC20 rewardToken;

    address owner;
    address payable crucible;

    VersionProxy proxy;
    VersionBeacon beacon;

    function setUp() public {
        // create base template
        Crucible baseCrucible = new Crucible();
        baseCrucible.initializeLock();

        proxy = new VersionProxy();
        beacon = new VersionBeacon(address(baseCrucible));

        CrucibleFactoryV2 crucibleFactory = new CrucibleFactoryV2(
            address(proxy), address(beacon)
        );

        owner = vm.addr(PRIVATE_KEY);

        vm.prank(owner);
        crucible = payable(crucibleFactory.create(0, owner));
    }

    function test_setup() public {
        // beacon starts at version 1, the base version.
        assertEq(beacon.getLatestVersion(), 1);
        assertEq(beacon.getVersionDescription(1), "base version");
    }

    function test_upgrade() public {
        // create template A
        MockCrucibleA mockCrucibleA = new MockCrucibleA();
        mockCrucibleA.initializeLock();

        assertEq(beacon.getLatestVersion(), 1);

        beacon.upgrade(address(mockCrucibleA), "mock crucible A");
        // increments the lastest version by 1
        assertEq(beacon.getLatestVersion(), 2);

        vm.prank(owner);
        BaseCrucible(payable(crucible)).changeVersion(2);

        assertEq(MockCrucibleA(crucible).leet(), 1337);

        // bleep is not defined in version 2, it should revert
        vm.expectRevert();
        MockCrucibleB(crucible).bleep();

        // create template B
        MockCrucibleB mockCrucibleB = new MockCrucibleB();
        mockCrucibleB.initializeLock();

        beacon.upgrade(address(mockCrucibleB), "mock crucible B");
        assertEq(beacon.getLatestVersion(), 3);

        vm.prank(owner);
        BaseCrucible(crucible).changeVersion(3);

        // now leet and bleep should work because they're defined in version 3
        assertEq(MockCrucibleB(crucible).leet(), 1337 * 2);
        assertEq(MockCrucibleB(crucible).bleep(), 1234);

        // switch back to version 2
        vm.prank(owner);
        BaseCrucible(crucible).changeVersion(2);

        // leet works but bleep doesn't
        assertEq(MockCrucibleA(crucible).leet(), 1337);
        vm.expectRevert();
        MockCrucibleB(crucible).bleep();
    }

    function test_upgradeByNonOwner() public {
        vm.expectRevert(VersionTemplate.OnlyAdmin.selector);
        BaseCrucible(payable(crucible)).changeVersion(2);
    }

    function test_upgradeToInvalidVersion() public {
        vm.startPrank(owner);
        vm.expectRevert(VersionTemplate.UndefinedVersion.selector);
        BaseCrucible(crucible).changeVersion(99);
    }

    function test_upgrade_InvalidImplementation() public {
        vm.expectRevert(IVersionBeacon.InvalidImplementation.selector);
        beacon.upgrade(address(owner), "invalid implementation");
    }

    function test_version_decriptions() public {

        // create template A
        MockCrucibleA version = new MockCrucibleA();
        version.initializeLock();

        assertEq(beacon.getVersionDescription(1), "base version");
        assertEq(beacon.getVersionDescription(2), "");

        beacon.upgrade(address(version), "version 1");
        assertEq(beacon.getVersionDescription(1), "base version");
        assertEq(beacon.getVersionDescription(2), "version 1");
    }

    function test_changeAdmin() public {

        address other = vm.addr(PRIVATE_KEY + 1);

        vm.prank(owner);
        VersionTemplate(crucible).changeAdmin(owner);

        vm.startPrank(other);
        vm.expectRevert(VersionTemplate.OnlyAdmin.selector);
        VersionTemplate(crucible).changeAdmin(other);
    }
}
