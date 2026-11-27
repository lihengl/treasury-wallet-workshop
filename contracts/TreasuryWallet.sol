// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice A 2-of-3 ETH treasury wallet for the Remix VM workshop.
contract TreasuryWallet {
    uint256 public constant REQUIRED_APPROVALS = 2;

    struct Payment {
        address payable recipient;
        uint256 amount;
        uint256 approvalCount;
        bool executed;
    }

    mapping(address => bool) public isOwner;
    mapping(uint256 => Payment) public payments;
    mapping(uint256 => mapping(address => bool)) public hasApproved;
    uint256 public paymentCount;

    event Deposit(address indexed sender, uint256 amount);
    event PaymentProposed(
        uint256 indexed paymentId,
        address indexed proposer,
        address indexed recipient,
        uint256 amount
    );
    event PaymentApproved(uint256 indexed paymentId, address indexed owner);
    event PaymentExecuted(uint256 indexed paymentId, address indexed executor);

    constructor(address owner1, address owner2, address owner3) {
        require(
            owner1 != address(0) && owner2 != address(0) && owner3 != address(0),
            "Owner cannot be zero"
        );
        require(
            owner1 != owner2 && owner1 != owner3 && owner2 != owner3,
            "Owners must be distinct"
        );

        isOwner[owner1] = true;
        isOwner[owner2] = true;
        isOwner[owner3] = true;
    }

    modifier onlyOwner() {
        require(isOwner[msg.sender], "Only an owner");
        _;
    }

    modifier pendingPayment(uint256 paymentId) {
        require(paymentId < paymentCount, "Unknown payment");
        require(!payments[paymentId].executed, "Payment already executed");
        _;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    function walletBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /// @notice Propose a payment in wei. The first payment ID is 0.
    /// @dev The proposer must send a separate transaction to approve.
    function proposePayment(address payable recipient, uint256 amount)
        external
        onlyOwner
        returns (uint256 paymentId)
    {
        require(recipient != address(0), "Recipient cannot be zero");
        require(recipient != address(this), "Recipient cannot be the wallet");
        require(amount > 0, "Amount must be positive");

        paymentId = paymentCount;
        payments[paymentId] = Payment(recipient, amount, 0, false);
        paymentCount++;

        emit PaymentProposed(paymentId, msg.sender, recipient, amount);
    }

    function approvePayment(uint256 paymentId)
        external
        onlyOwner
        pendingPayment(paymentId)
    {
        require(!hasApproved[paymentId][msg.sender], "Owner already approved");

        hasApproved[paymentId][msg.sender] = true;
        payments[paymentId].approvalCount++;

        emit PaymentApproved(paymentId, msg.sender);
    }

    function executePayment(uint256 paymentId)
        external
        onlyOwner
        pendingPayment(paymentId)
    {
        Payment storage payment = payments[paymentId];
        require(payment.approvalCount >= REQUIRED_APPROVALS, "Need two approvals");
        require(address(this).balance >= payment.amount, "Insufficient wallet balance");

        // Mark it executed before handing control to the recipient.
        payment.executed = true;

        // If the transfer fails, the revert also restores the execution flag.
        (bool sent, ) = payment.recipient.call{value: payment.amount}("");
        require(sent, "ETH transfer failed");

        emit PaymentExecuted(paymentId, msg.sender);
    }
}