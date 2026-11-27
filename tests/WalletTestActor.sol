// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../contracts/TreasuryWallet.sol";

// Each instance gives the wallet a distinct msg.sender.
contract WalletTestActor {
    receive() external payable {}

    function propose(TreasuryWallet wallet, address payable recipient, uint256 amount) external {
        wallet.proposePayment(recipient, amount);
    }

    function approve(TreasuryWallet wallet, uint256 paymentId) external {
        wallet.approvePayment(paymentId);
    }

    function execute(TreasuryWallet wallet, uint256 paymentId) external {
        wallet.executePayment(paymentId);
    }
}