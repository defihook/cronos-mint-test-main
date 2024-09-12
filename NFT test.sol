// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";


contract TestNFT is ERC721Enumerable, Ownable, ReentrancyGuard {
    using Strings for uint256;
    
    // Let's Assume NFT totalAmount is 5000

    // Private
    uint16[5000] public nftIds;
    
    // Public
    mapping(address => uint256) public rewardDebt;

    string public uriPrefix = "";
    string public uriSuffix = ".json";
    string public hiddenMetadataUri;

    uint256 public price = 10**16;                                  /// 0.01ETH
    uint256 public maxSupply = 5000;
    uint256 public maxMintAmountPerTx = 10;                         /// Max Mint Amount Per Tx is 10
    address public ownerAddress = ;

    uint256 public accPerShare;                                     /// Accumulate Per Share

    // Define the recipient wallets and their percentages
    address payable[] public recipientWallets;
    uint256[] public recipientPercentages;

    // Public Boolean Variables
    bool public paused = false;
    bool public revealed = true;

    constructor() ERC721("TestNFT", "TNFT") {
        setHiddenMetadataUri(
            ""
        );
    }

    //======================  Modifier  =======================//

    // Modifier for mint compliance max Mint amount and total Amount
    modifier mintCompliance(uint256 _mintAmount) {
        require(
            _mintAmount > 0 && _mintAmount <= maxMintAmountPerTx,
            "Invalid mint amount!"
        );
        require(
            totalSupply() + _mintAmount <= maxSupply,
            "Max supply exceeded!"
        );
        _;
    }

    // Modifier for mint price compliance
    modifier mintPriceCompliance(uint256 _mintAmount) {
        require(msg.value >= price * _mintAmount, "Insufficient funds!");
        _;
    }

    //======================  Main Function  =======================//

    function mint(uint256 _mintAmount)
        public
        payable
        mintCompliance(_mintAmount)
        mintPriceCompliance(_mintAmount)
    {
        require(!paused, "The contract is paused!");
        require(msg.value >= price * _mintAmount, "Price insufficient!");

        // Royalty Amount to be distributed
        uint256 _shareAmount = msg.value * 15 / 100;
        address _sender = msg.sender;

        // Reset the accPerShare and minter's rewardDebt
        payable(_sender).transfer(accPerShare*balanceOf(_sender) - rewardDebt[_sender]);
        rewardDebt[_sender] = accPerShare * (_mintAmount + balanceOf(_sender));
        uint256 _accPerShare = accPerShare + (_shareAmount / (totalSupply()+_mintAmount));
        accPerShare = _accPerShare;

        // Multiple mint function call
        _mintLoop(_sender, _mintAmount);
    }

    // Claim the Reward which is distributed to users
    function claim() external {
        // Get Claimable reward amount
        address _sender = msg.sender;
        uint256 _amount = accPerShare * balanceOf(_sender) - rewardDebt[_sender];
        rewardDebt[_sender] = accPerShare * balanceOf(_sender);

        // Send reward amount to users
        payable(msg.sender).transfer(_amount);
    }

    // Get the claimable reward amount which is distributed to users
    function claimableAmount(address _claimer) public view returns(uint256) {
        // Get Claimable reward amount
        uint256 _amount = accPerShare * balanceOf(_claimer) - rewardDebt[_claimer];
        return _amount;
    }
   
    // Get the NFT token Ids which the owner holds
    function walletOfOwner(address _owner)
        public
        view
        returns (uint256[] memory)
    {
        uint256 ownerTokenCount = balanceOf(_owner);
        uint256[] memory ownedTokenIds = new uint256[](ownerTokenCount);

        for (uint256 i = 0; i < ownerTokenCount; i++) {
            uint256 tokenIdAtIndex = tokenOfOwnerByIndex(_owner, i);
            ownedTokenIds[i] = tokenIdAtIndex;
        }

        return ownedTokenIds;
    }

    // Get TokenURI function
    function tokenURI(uint256 _tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(
            _exists(_tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        if (revealed == false) {
            return hiddenMetadataUri;
        }

        string memory currentBaseURI = _baseURI();
        return
            bytes(currentBaseURI).length > 0
                ? string(
                    abi.encodePacked(
                        currentBaseURI,
                        _tokenId.toString(),
                        uriSuffix
                    )
                )
                : "";
    }

    // Override Transfer function to change the rewardDebt - To calculate distribution amount exactly
    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override(ERC721) {
        // Reset the `from` account's rewardDebt
        uint256 _amount = accPerShare * balanceOf(from) - rewardDebt[from];
        rewardDebt[from] = accPerShare * (balanceOf(from) - 1);

        // Reset the `to` account's rewardDebt
        uint256 _amountOut = accPerShare * balanceOf(to) - rewardDebt[to];
        rewardDebt[to] = accPerShare * (balanceOf(to) + 1);

        // Transfer reward amount to the `from`, `to` accounts
        payable(from).transfer(_amount);
        payable(to).transfer(_amountOut);

        super._transfer(from, to, tokenId);
    }

    function burn(uint256 tokenId) public virtual {
        //solhint-disable-next-line max-line-length
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: caller is not token owner or approved");
        _burn(tokenId);
    }

    //======================  OnlyOwner Function  =======================//

    // Set Reveal function to see the metadata
    function setRevealed(bool _state) public onlyOwner {
        revealed = _state;
        emit Revealed(_state);
    }

    // Set the mint price 
    function setPrice(uint256 _price) public onlyOwner {
        price = _price;
    }

    // Set the Max mint amount per Tx
    function setMaxMintAmountPerTx(uint256 _maxMintAmountPerTx)
        public
        onlyOwner
    {
        maxMintAmountPerTx = _maxMintAmountPerTx;
    }

    // Set the Hiddend MetadataUri
    function setHiddenMetadataUri(string memory _hiddenMetadataUri)
        public
        onlyOwner
    {
        hiddenMetadataUri = _hiddenMetadataUri;
    }

    // Set the URI prefix
    function setUriPrefix(string memory _uriPrefix) public onlyOwner {
        uriPrefix = _uriPrefix;
    }

    // Set the URI suffix
    function setUriSuffix(string memory _uriSuffix) public onlyOwner {
        uriSuffix = _uriSuffix;
    }

    // Set the Pause/Run toggle function
    function setPaused(bool _state) public onlyOwner {
        paused = _state;
        emit Paused(_state);
    }
    
    // Modified withdraw function to distribute the withdrawn amount based on the specified percentages
    function withdraw() public onlyOwner nonReentrant {
      
        require(address(this).balance > 0, "No funds to withdraw!");

        uint256 contractBalance = address(this).balance;
      
        for (uint256 i = 0; i < recipientWallets.length; i++) {
          uint256 amountToSend = (contractBalance * recipientPercentages[i]) / 100;
          (bool sent, ) = recipientWallets[i].call{value: amountToSend}("");
          require(sent, "Failed to send funds to recipient");
        }
    }

    // Set the recipient wallets and their corresponding percentages
    function setRecipientWalletsAndPercentages(address payable[] calldata _recipientWallets, uint256[] calldata _recipientPercentages) external onlyOwner {
        require(_recipientWallets.length == _recipientPercentages.length, "Input arrays must have the same length");
        uint256 totalPercentage = 0;
        for (uint256 i = 0; i < _recipientPercentages.length; i++) {
          totalPercentage += _recipientPercentages[i];
        }
        require(totalPercentage == 100, "Total percentages must equal 100");

        recipientWallets = _recipientWallets;
        recipientPercentages = _recipientPercentages;
    }

    //======================  Internal/Private Function  =======================//

    // Internal Mint Loop function
    function _mintLoop(address _receiver, uint256 _mintAmount) internal {
        for (uint256 i = 0; i < _mintAmount; i++) {
            uint256 _random = uint256(
                keccak256(
                    abi.encodePacked(
                        totalSupply(),
                        msg.sender,
                        block.timestamp,
                        blockhash(block.number - 1)
                    )
                )
            );
            uint256 _randomId = _pickRandomUniqueId(_random);
            _safeMint(_receiver, _randomId);
        }
    }

    // Get the baseURI function 
    function _baseURI() internal view virtual override returns (string memory) {
        return uriPrefix;
    }

    // Private - get Random Unique ID function
    function _pickRandomUniqueId(uint256 random) private returns (uint256) {
        uint256 len = nftIds.length - (totalSupply());
        require(len > 0, "no ids left");
        uint256 randomIndex = random % len;
        uint256 id = nftIds[randomIndex] != 0
            ? nftIds[randomIndex]
            : randomIndex;
        id++; // 1 indexed tokenId
        nftIds[randomIndex] = uint16(
            nftIds[len - 1] == 0 ? len - 1 : nftIds[len - 1]
        );
        nftIds[len - 1] = 0;
        return id;
    }
}
