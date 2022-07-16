// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Counters.sol";
import "hardhat/console.sol";
import "./Property.sol";

contract Registry {
    using Counters for Counters.Counter;

    // =========== Data Structures ===========

    Counters.Counter nProperties;
    address pptContract;

    struct PropertyInfo {
        uint price; // unit = wei
        string location;
        uint size; // unit = squarefeet
        bool available;
    }

    mapping(uint256 => PropertyInfo) properties;

    struct Purchase {
        uint pid;
        address buyer;
        address owner;
        uint price;
    }

    Purchase[] purchases;

    // =========== Events ===========

    event NewPropertyEvent(
        uint id,
        address owner,
        uint price,
        string location,
        uint size
    );

    event BuyPropertyEvent(
        address buyer,
        uint pid,
        uint price
    );

    event PropertyAvailabilityEvent(
        uint pid,
        bool available
    );

    // =========== Functions ===========


    constructor(address _pptContract) {
        nProperties.reset();
        pptContract = _pptContract;
    }


    function addProperty(
        uint _price,
        string memory _location,
        uint _size
    ) public {
        // Create new NFT
        uint256 pid = nProperties.current();
        nProperties.increment();
        Property(pptContract).safeMint(msg.sender, pid);

        // Store property metadata
        PropertyInfo memory prop = PropertyInfo(
            _price,
            _location,
            _size,
            true  // Default availability
        );
        properties[pid] = prop;

        emit NewPropertyEvent(
            pid, 
            msg.sender,
            _price,
            _location,
            _size
        );
    }


    function buyProperty (uint pid) public payable {
        address owner = Property(pptContract).ownerOf(pid);

        // Check if property is available for buying
        require(
            properties[pid].available, 
            "Registry: Property not available for buying"
        );

        // Check if sufficient money was sent
        require(
            msg.value >= properties[pid].price,
            "Registry: Not enough money provided for buying"
        );

        // Update property status
        properties[pid].available = false;

        // Send money to owner
        (bool success, ) = address(owner).call{ value: msg.value }("");
        require(success, "Registry: Failed to send money to owner");

        // Transfer property (PPT) to new owner
        // NOTE: Contract needs allowance from owner to perform transfer
        Property(pptContract).safeTransferFrom(owner, msg.sender, pid);

        Purchase memory pur = Purchase(pid, msg.sender, owner, properties[pid].price);
        purchases.push(pur);

        emit BuyPropertyEvent(
            msg.sender,
            pid,
            properties[pid].price
        );
    }

    function getPurchases() public view returns (Purchase[] memory) {
        return purchases;
    }

    function getProperties() public view returns (PropertyInfo[] memory){
        PropertyInfo[] memory result = new PropertyInfo[](nProperties.current());

        for (uint i=0; i < nProperties.current(); i++) {
            result[i] = properties[i];
        }

        return result;
    }


    function setPropertyAvailability (uint pid, bool avl) public {
        // Check if caller is owner
        require(
            Property(pptContract).ownerOf(pid) == msg.sender,
            "Registry: Property not owned by caller"
        );

        properties[pid].available = avl;
        
        emit PropertyAvailabilityEvent(
            pid,
            avl
        );
    }

}