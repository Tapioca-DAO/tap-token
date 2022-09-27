// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import './interfaces/IOFT.sol';
import './interfaces/IoTapOFT.sol';
import './interfaces/ITwapOracle.sol';
import './OFT721/ONFT721.sol';

contract oTapOFT is ONFT721, IoTapOFT {
    // ==========
    // *DATA*
    // ==========

    uint256 public nextIndexId;

    IOFT public immutable tap;
    ITwapOracle public tapOracle;
    address public optionsContract;
    address public treasury;

    //index=>option
    mapping(uint256 => Option) public override options;

    uint256 public totalAmount;
    uint256 public expiryTimestamp = 1 days;
    uint256 public discountRatio = 50;

    // ==========
    // *EVENTS*
    // ==========
    event DiscountUpdated(uint256 _oldDiscount, uint256 _newDiscount);
    event ExpiryUpdated(uint256 _oldExpiry, uint256 _newExpiry);
    event OptionsContractUpdate(address indexed _old, address indexed _new);
    event Claimed(address indexed _for, uint256 _id, uint256 _amount, uint256 _expiry, uint256 _redeemableAmount);
    event Executed(address indexed _for, uint256 _id, uint256 _redeemedAmount, uint256 _treasuryAmount);

    // ==========
    // * METHODS *
    // ==========
    /// @notice Creates oTapOFT NFT contract
    /// @param _layerZeroEndpoint LZ endpoint address
    /// @param _startMintId First NFT index
    /// @param _tapToken TAP OFT address
    /// @param _tapOracle TWAP TAP oracle
    constructor(
        address _layerZeroEndpoint,
        uint256 _startMintId,
        IOFT _tapToken,
        ITwapOracle _tapOracle
    ) ONFT721('Options TAP', 'oTAP', _layerZeroEndpoint) {
        require(address(_tapToken) != address(0), 'token not valid');
        require(address(_tapOracle) != address(0), 'oracle not valid');
        nextIndexId = _startMintId;
        tap = _tapToken;
        tapOracle = _tapOracle;
    }

    ///-- View methods --
    /// @notice returns strike amount _tapAmount
    /// @dev takes `discountRatio` into account
    /// @param _tapAmount the amount of tap to calculate for
    /// @param _oracleData TWAP TAP oracle
    function calc(uint256 _tapAmount, bytes calldata _oracleData) public view override returns (uint256) {
        (bool success, uint256 spotPrice) = tapOracle.peek(_oracleData);
        require(success, 'price retrieval failed');
        uint256 strikePrice = (spotPrice * discountRatio) / 100;
        return _tapAmount / strikePrice;
    }

    ///-- Write methods --
    /// @notice claims oTap and sets expiry and strike price for it
    /// @param _for receiver of oTapOFT
    /// @param _amount TAP amount to be considered
    /// @param _oracleData TWAP TAP price retrieval data
    /// @return id the oTapOFT minted
    function claim(
        address _for,
        uint256 _amount,
        bytes calldata _oracleData
    ) external override returns (uint256 id) {
        require(msg.sender == optionsContract, 'unauthorized');
        id = nextIndexId;

        Option memory _optionData;
        _optionData.exercised = false;
        _optionData.amount = _amount;
        _optionData.expiry = block.timestamp + expiryTimestamp;
        _optionData.redeemableAmount = calc(_amount, _oracleData);
        options[id] = _optionData;
        nextIndexId++;
        _safeMint(_for, id);

        emit Claimed(_for, id, _amount, _optionData.expiry, _optionData.redeemableAmount);
    }

    /// @notice executes option
    /// @param _for receiver of TapOFT
    /// @param _id oTapOFT index to execute for
    /// @return transferableAmount the TAP amount `_for` receives
    /// @return treasuryAmount the TAP amount `treasury` receives
    function execute(address _for, uint256 _id) external override returns (uint256 transferableAmount, uint256 treasuryAmount) {
        require(msg.sender == optionsContract, 'unauthorized');
        address oTapOwner = ownerOf(_id);
        require(oTapOwner == _for, 'unauthorized for item');
        require(options[_id].amount > 0, 'entry not valid');
        require(options[_id].expiry >= block.timestamp && !options[_id].exercised, 'execution not possible');
        options[_id].exercised = true;
        transferableAmount = options[_id].redeemableAmount;
        treasuryAmount = transferableAmount - options[_id].amount;
        safeTransferFrom(msg.sender, address(this), _id);

        emit Executed(_for, _id, transferableAmount, treasuryAmount);
    }

    ///-- Owner methods --
    /// @notice updates expiry timestamp
    /// @dev callable by owner
    /// @param _newExpiry the new timestamp
    function updateExpiry(uint256 _newExpiry) external onlyOwner {
        emit ExpiryUpdated(expiryTimestamp, _newExpiry);
        expiryTimestamp = _newExpiry;
    }

    /// @notice updates discount ratio
    /// @dev callable by owner
    /// @param _newDiscount the new discount ratio
    function updateDiscount(uint256 _newDiscount) external onlyOwner {
        require(_newDiscount > 0, 'not valid');
        emit DiscountUpdated(discountRatio, _newDiscount);
        discountRatio = _newDiscount;
    }

    /// @notice updates options contract
    /// @dev callable by owner
    /// @param _optionsContract the TapiocaOptions address
    function setOptionsContract(address _optionsContract) external onlyOwner {
        require(_optionsContract != address(0), 'options contract not valid');
        emit OptionsContractUpdate(optionsContract, _optionsContract);
        optionsContract = _optionsContract;
    }
}
