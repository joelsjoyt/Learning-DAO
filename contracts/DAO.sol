// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract DAO is ReentrancyGuard, AccessControl {
    /*
        Manages roles in the DAO
        Deposit > X ETH stakeholder
        Deposit < X ETH contributor
    */

    bytes32 private immutable CONTRIBUTOR_ROLE = keccak256("CONTRIBUTOR");
    bytes32 private immutable STAKEHOLDER_ROLE = keccak256("STAKEHOLDER");

    uint256 immutable MINIMUM_STAKEHOLDER_CONTRIBUTION = 1 ether;
    uint32 immutable MIN_VOTE_DURATION = 3 minutes;

    uint32 totalProposals;
    uint256 public daoBalance;

    mapping(uint256 => ProposalStruct) private raisedProposals;
    mapping(address => uint256[]) private stakeholderVotes;
    mapping(uint256 => VotedStruct[]) private votedOn;
    mapping(address => uint256) private contributors;
    mapping(address => uint256) private stakeholders;

    struct ProposalStruct {
        uint id;
        uint amount;
        uint duration;
        uint upVotes;
        uint downVotes;
        string title;
        string description;
        bool isPassed;
        bool isPaid;
        address payable beneficary;
        address proposer;
        address executor;
    }

    struct VotedStruct {
        address voter;
        uint256 timestamp;
        bool chosen;
    }

    event Action(
        address indexed initiator,
        bytes32 role,
        string message,
        address indexed benificary,
        uint256 amount
    );

    //Modifier for providing access to stakeholders only
    modifier stakeholderOnly(string memory message) {
        require(hasRole(STAKEHOLDER_ROLE, msg.sender), message);
        _;
    }

    //Modifier for providing acces to contributors only
    modifier contributorOnly(string memory message) {
        require(hasRole(CONTRIBUTOR_ROLE, msg.sender), message);
        _;
    }

    function createPorposal(
        string memory title,
        string memory description,
        address benificary,
        uint amount
    )
        external
        stakeholderOnly("Proposal creation allowed for stakeholders only")
    {
        uint32 proposalId = totalProposals++;
        ProposalStruct storage proposal = raisedProposals[proposalId];

        proposal.id = proposalId;
        proposal.beneficary = payable(benificary);
        proposal.proposer = payable(msg.sender);
        proposal.title = title;
        proposal.description = description;
        proposal.amount = amount;
        proposal.duration = block.timestamp + MIN_VOTE_DURATION;

        emit Action(
            msg.sender,
            STAKEHOLDER_ROLE,
            "PROPOSAL RAISED",
            benificary,
            amount
        );
    }

    function handleVoting(ProposalStruct storage proposal) private {
        if (proposal.isPassed || proposal.duration <= block.timestamp) {
            proposal.isPassed = true;
            revert("Proposal duration expired");
        }

        uint256[] memory tempVotes = stakeholderVotes[msg.sender];

        for (uint votes = 0; votes < tempVotes.length; votes++) {
            if (proposal.id == tempVotes[votes])
                revert("Multiple votes are not allowed");
        }
    }

    function Vote(
        uint256 proposalId,
        bool chosen
    )
        external
        stakeholderOnly("Unauthorided Access: Not a Stakeholder")
        returns (VotedStruct memory)
    {
        ProposalStruct storage proposal = raisedProposals[proposalId];
        handleVoting(proposal);

        if (chosen) proposal.upVotes++;
        else proposal.downVotes++;

        stakeholderVotes[msg.sender].push(proposal.id);

        votedOn[proposal.id].push(
            VotedStruct(msg.sender, block.timestamp, chosen)
        );

        emit Action(
            msg.sender,
            STAKEHOLDER_ROLE,
            "PROPOSAL VOTE",
            proposal.beneficary,
            proposal.amount
        );

        return VotedStruct(msg.sender, block.timestamp, chosen);
    }

    function payTo(address to, uint256 amount) internal returns (bool) {
        (bool success, ) = payable(to).call{value: amount}("");
        require(success, "Payment failed");
        return true;
    }

    function payToBenificary(
        uint proposalId
    )
        public
        stakeholderOnly("Unauthorided Access: Not a Stakeholder")
        nonReentrant
        returns (uint256)
    {
        ProposalStruct storage proposal = raisedProposals[proposalId];
        require(daoBalance >= proposal.amount, "Insufficent DAO balance");

        if (proposal.isPaid) revert("Proposal is already paid");
        if (proposal.upVotes <= proposal.downVotes) revert("Insufficent Votes");

        proposal.isPaid = true;
        proposal.executor = msg.sender;
        daoBalance -= proposal.amount;

        payTo(proposal.beneficary, proposal.amount);

        emit Action(
            msg.sender,
            STAKEHOLDER_ROLE,
            "PAYMENT TRANSFERED",
            proposal.beneficary,
            proposal.amount
        );

        return daoBalance;
    }

    function contribute() public payable {
        require(msg.value > 0, "Contrubution should be greater than 0");

        //Check if contributor is eligible to become a stakeholder
        if (!hasRole(STAKEHOLDER_ROLE, msg.sender)) {
            uint256 totalContributed = contributors[msg.sender] + msg.value;

            if (totalContributed >= MINIMUM_STAKEHOLDER_CONTRIBUTION) {
                stakeholders[msg.sender] = totalContributed;
                _grantRole(STAKEHOLDER_ROLE, msg.sender);
            }

            contributors[msg.sender] += msg.value;
            _grantRole(CONTRIBUTOR_ROLE, msg.sender);
        } else {
            //StakeHolder is also a contributor
            contributors[msg.sender] += msg.value;
            stakeholders[msg.sender] += msg.value;
        }

        daoBalance += msg.value;

        emit Action(
            msg.sender,
            CONTRIBUTOR_ROLE,
            "CONTRIBUTION RECEIVED",
            address(this),
            msg.value
        );
    }

    function getProposals()
        external
        view
        returns (ProposalStruct[] memory proposals)
    {
        proposals = new ProposalStruct[](totalProposals);

        for (uint256 i = 0; i < totalProposals; i++) {
            proposals[i] = raisedProposals[i];
        }
    }

    function getProposal(
        uint256 proposalId
    ) public view returns (ProposalStruct memory) {
        return raisedProposals[proposalId];
    }

    function getVotesOf(
        uint256 proposalId
    ) public view returns (VotedStruct[] memory) {
        return votedOn[proposalId];
    }

    function getStakeholderVotes()
        external
        view
        stakeholderOnly("Unauthorided Access: Not a Stakeholder")
        returns (uint[] memory)
    {
        return stakeholderVotes[msg.sender];
    }

    function getStakeholderBalance()
        external
        view
        stakeholderOnly("Unauthorided Access: Not a Stakeholder")
        returns (uint256)
    {
        return stakeholders[msg.sender];
    }
}
