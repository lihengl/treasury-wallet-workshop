// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "remix_tests.sol";
import "../contracts/TreasuryWallet.sol";

import "./WalletTestActor.sol";

contract TreasuryWalletTest {
    address payable private vendor;
    TreasuryWallet private wallet;
    WalletTestActor private finance;
    WalletTestActor private risk;
    WalletTestActor private outsider;

    function beforeEach() public {
        finance = new WalletTestActor();
        risk = new WalletTestActor();
        outsider = new WalletTestActor();
        vendor = payable(address(new WalletTestActor()));
        wallet = new TreasuryWallet(address(this), address(finance), address(risk));
    }

    function rejectsInvalidOwners() public {
        try new TreasuryWallet(address(this), address(this), address(risk)) {
            Assert.ok(false, "Duplicate owners must be rejected");
        } catch Error(string memory reason) {
            Assert.equal(reason, "Owners must be distinct", "Duplicate owner revert reason");
        }

        try new TreasuryWallet(address(this), address(0), address(risk)) {
            Assert.ok(false, "Zero owner must be rejected");
        } catch Error(string memory reason) {
            Assert.equal(reason, "Owner cannot be zero", "Zero owner revert reason");
        }
    }

    function rejectsNonOwners() public {
        try outsider.propose(wallet, vendor, 1 ether) {
            Assert.ok(false, "Non-owner proposed a payment");
        } catch Error(string memory reason) {
            Assert.equal(reason, "Only an owner", "Propose access control");
        }

        uint256 id = wallet.proposePayment(vendor, 1 ether);
        try outsider.approve(wallet, id) {
            Assert.ok(false, "Non-owner approved a payment");
        } catch Error(string memory reason) {
            Assert.equal(reason, "Only an owner", "Approval access control");
        }

        approveTwice(id);
        try outsider.execute(wallet, id) {
            Assert.ok(false, "Non-owner executed a payment");
        } catch Error(string memory reason) {
            Assert.equal(reason, "Only an owner", "Execution access control");
        }
    }

    function rejectsUnknownPayment() public {
        try wallet.approvePayment(0) {
            Assert.ok(false, "Approved an unknown payment");
        } catch Error(string memory reason) {
            Assert.equal(reason, "Unknown payment", "Unknown approval revert reason");
        }

        try wallet.executePayment(0) {
            Assert.ok(false, "Executed an unknown payment");
        } catch Error(string memory reason) {
            Assert.equal(reason, "Unknown payment", "Unknown execution revert reason");
        }
    }

    /// #value: 3000000000000000000
    function requiresTwoDistinctApprovals() public payable {
        fundWallet(msg.value);
        Assert.equal(wallet.walletBalance(), 3 ether, "Wallet should hold 3 ETH");

        uint256 id = wallet.proposePayment(vendor, 1 ether);
        Assert.equal(id, 0, "First payment ID");
        (address recipient, uint256 amount, uint256 approvals, bool executed) = wallet.payments(id);
        Assert.equal(recipient, address(vendor), "Stored recipient");
        Assert.equal(amount, 1 ether, "Stored amount");
        Assert.equal(approvals, 0, "Proposal starts with zero approvals");
        Assert.ok(!executed, "Proposal starts pending");

        wallet.approvePayment(id);
        try wallet.approvePayment(id) {
            Assert.ok(false, "Owner approved the same payment twice");
        } catch Error(string memory reason) {
            Assert.equal(reason, "Owner already approved", "Repeat approval revert reason");
        }

        try wallet.executePayment(id) {
            Assert.ok(false, "One approval should be insufficient");
        } catch Error(string memory reason) {
            Assert.equal(reason, "Need two approvals", "Threshold revert reason");
        }
    }

    /// #value: 3000000000000000000
    function paysOnceAfterTwoApprovals() public payable {
        fundWallet(msg.value);
        uint256 vendorBefore = vendor.balance;
        uint256 id = wallet.proposePayment(vendor, 1 ether);
        approveTwice(id);

        (, , uint256 approvals, bool executed) = wallet.payments(id);
        Assert.equal(approvals, 2, "Two approvals recorded");
        Assert.ok(!executed, "Approved payment remains pending");
        Assert.equal(wallet.walletBalance(), 3 ether, "Approvals leave wallet balance intact");
        Assert.equal(vendor.balance, vendorBefore, "Vendor balance stays the same before execution");

        risk.execute(wallet, id);
        (, , , executed) = wallet.payments(id);
        Assert.ok(executed, "Payment marked executed");
        Assert.equal(wallet.walletBalance(), 2 ether, "Wallet paid 1 ETH");
        Assert.equal(vendor.balance, vendorBefore + 1 ether, "Vendor received 1 ETH");

        try risk.execute(wallet, id) {
            Assert.ok(false, "Payment executed twice");
        } catch Error(string memory reason) {
            Assert.equal(reason, "Payment already executed", "Repeat execution revert reason");
        }
        Assert.equal(vendor.balance, vendorBefore + 1 ether, "Vendor was paid once");
    }

    /// #value: 1000000000000000000
    function canRetryAfterFunding() public payable {
        uint256 id = wallet.proposePayment(vendor, 1 ether);
        approveTwice(id);
        try wallet.executePayment(id) {
            Assert.ok(false, "Unfunded wallet executed a payment");
        } catch Error(string memory reason) {
            Assert.equal(reason, "Insufficient wallet balance", "Unfunded execution revert reason");
        }

        fundWallet(msg.value);
        uint256 vendorBefore = vendor.balance;
        wallet.executePayment(id);
        Assert.equal(vendor.balance, vendorBefore + 1 ether, "Wallet paid after funding");
        Assert.equal(wallet.walletBalance(), 0, "Wallet spent the deposit");
    }

    /// #value: 1000000000000000000
    function preservesStateWhenRecipientRejectsETH() public payable {
        fundWallet(msg.value);
        // This test contract has no receive or fallback function.
        uint256 id = wallet.proposePayment(payable(address(this)), 1 ether);
        approveTwice(id);

        try wallet.executePayment(id) {
            Assert.ok(false, "Payment to a rejecting recipient succeeded");
        } catch Error(string memory reason) {
            Assert.equal(reason, "ETH transfer failed", "Rejected transfer revert reason");
        }

        (, , uint256 approvals, bool executed) = wallet.payments(id);
        Assert.equal(approvals, 2, "Failed execution preserves approvals");
        Assert.ok(!executed, "Failed execution leaves payment pending");
        Assert.equal(wallet.walletBalance(), 1 ether, "Failed transfer preserves wallet balance");
    }

    function approveTwice(uint256 id) private {
        wallet.approvePayment(id);
        finance.approve(wallet, id);
    }

    function fundWallet(uint256 amount) private {
        (bool funded, ) = address(wallet).call{value: amount}("");
        require(funded, "Test funding failed");
    }
}