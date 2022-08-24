// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

/// @title CRUD example for memberships
/// @author K.L
/// @notice Use this contract for membership management through authorized gateways
/// @dev Most function calls are executed by authorized gateways.
contract Register is Initializable, AccessControlUpgradeable {
    /// @notice Membership data structure to store
    /// @param creationTimestamp User address
    /// @param username Username for a user
    /// @param creationTimestamp Timestamp when a membership created
    /// @param expirationTimestamp Timestamp when a membership expired
    struct Membership {
        address user;
        bytes32 username;
        uint256 creationTimestamp;
        uint256 expirationTimestamp;
    }

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant AUTHOR_ROLE = keccak256("AUTHOR_ROLE");
    uint256 private constant EXPIRATION_TIME = 30 days;

    uint256 private _nonce;
    mapping(uint256 => Membership) private _membershipById;
    mapping(address => uint256) private _membershipIdByUser;

    modifier validate(uint256 id_) {
        require(
            _membershipById[id_].user == msg.sender,
            "Reg: MemberMismatched"
        );
        require(
            _membershipById[id_].expirationTimestamp > block.timestamp,
            "Reg: MembershipExpired"
        );
        _;
    }

    modifier onlyAdmin() {
        require(hasRole(ADMIN_ROLE, msg.sender), "Reg: NoAdmin");
        _;
    }

    modifier onlyAuthor() {
        require(hasRole(AUTHOR_ROLE, msg.sender), "Reg: NoAuthor");
        _;
    }

    function initialize() public initializer {
        __AccessControl_init();

        _setupRole(ADMIN_ROLE, msg.sender);
        _setRoleAdmin(AUTHOR_ROLE, ADMIN_ROLE);

        _nonce = 1;
    }

    function _stringToBytes32(string memory str_)
        internal
        pure
        returns (bytes32 result)
    {
        require(
            bytes(str_).length > 2 && bytes(str_).length <= 32,
            "Reg: InvalidUsername"
        );
        bytes memory tempEmptyStringTest = bytes(str_);
        if (tempEmptyStringTest.length == 0) {
            return 0x0;
        }

        assembly {
            result := mload(add(str_, 32))
        }
    }

    function _bytes32ToString(bytes32 bytes_)
        internal
        pure
        returns (string memory)
    {
        uint256 i;
        while (i < 32 && bytes_[i] != 0) {
            i++;
        }
        bytes memory bytesArray = new bytes(i);
        for (i = 0; i < 32 && bytes_[i] != 0; i++) {
            bytesArray[i] = bytes_[i];
        }
        return string(bytesArray);
    }

    /// @notice Create a list of membership by author
    /// @param users_ list of user address to create membership
    /// @param usernames_ list of userename to create membership
    function create(address[] memory users_, string[] memory usernames_)
        external
        onlyAuthor
    {
        require(users_.length == usernames_.length, "Reg: DataMismatched");
        uint256 i;
        address userAddr;
        Membership memory newMember;
        uint256 current = block.timestamp;
        newMember.creationTimestamp = current;
        newMember.expirationTimestamp = current + EXPIRATION_TIME; // 30 days expriation time
        for (; i < users_.length; i++) {
            userAddr = users_[i];
            require(userAddr != address(0), "Reg: InvalidUser");
            require(
                _membershipIdByUser[userAddr] == 0,
                "Reg: DuplicatedMember"
            );
            newMember.user = userAddr;
            _membershipIdByUser[userAddr] = _nonce;
            newMember.username = _stringToBytes32(usernames_[i]);
            _membershipById[_nonce++] = newMember;
        }
    }

    /// @notice Update a list of membership by author
    /// @param ids_ list of membership id to update membership
    /// @param users_ list of user address to update membership
    /// @param usernames_ list of username to update membership
    /// @param creationTimestamps_ list of creation timestamp to update membership
    function update(
        uint256[] memory ids_,
        address[] memory users_,
        string[] memory usernames_,
        uint256[] memory creationTimestamps_
    ) external onlyAuthor {
        require(ids_.length == users_.length, "Reg: DataMismatched");
        require(users_.length == usernames_.length, "Reg: DataMismatched");
        require(
            usernames_.length == creationTimestamps_.length,
            "Reg: DataMismatched"
        );
        uint256 i;
        uint256 id;
        for (; i < ids_.length; i++) {
            id = ids_[i];
            Membership storage member = _membershipById[id];
            require(member.user != address(0), "Reg: Unavailable");
            require(users_[i] != address(0), "Reg: InvalidUser");
            member.user = users_[i];
            member.username = _stringToBytes32(usernames_[i]);
            member.creationTimestamp = creationTimestamps_[i];
            member.expirationTimestamp =
                creationTimestamps_[i] +
                EXPIRATION_TIME;
        }
    }

    /// @notice Get membership info by membership id
    /// @param id_ list of membership id to update membership
    /// @return user User address
    /// @return username Username
    /// @return creationTimestamp Created timestamp
    /// @return expirationTimestamp Expired timestamp
    function get(uint256 id_)
        external
        view
        returns (
            address user,
            string memory username,
            uint256 creationTimestamp,
            uint256 expirationTimestamp
        )
    {
        Membership memory member = _membershipById[id_];
        return (
            member.user,
            _bytes32ToString(member.username),
            member.creationTimestamp,
            member.expirationTimestamp
        );
    }

    /// @notice Remove a list of membership by author
    /// @param ids_ list of membership id to remove membership
    function remove(uint256[] memory ids_) external onlyAuthor {
        uint256 i;
        uint256 id;
        address userAddr;
        for (; i < ids_.length; i++) {
            id = ids_[i];
            userAddr = _membershipById[id].user;
            require(_membershipIdByUser[userAddr] != 0, "Reg: NoMembership");
            delete _membershipById[id];
            delete _membershipIdByUser[userAddr];
        }
    }

    /// @notice Get membership id by user address
    /// @param user user address to get a membership
    /// @return id Membership id of a provided user
    function getMembershipIdByUser(address user) public view returns (uint256) {
        return _membershipIdByUser[user];
    }

    /// @notice Change username of membership by user
    /// @param id_ Membership id of user
    /// @param username_ new username of membership for user
    function change(uint256 id_, string memory username_)
        external
        validate(id_)
    {
        _membershipById[id_].username = _stringToBytes32(username_);
    }
}
