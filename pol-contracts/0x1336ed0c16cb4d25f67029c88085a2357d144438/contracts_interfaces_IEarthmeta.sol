// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

/// @title IEarthmeta interface.
/// @author Earthmeta 2024.
interface IEarthmeta {
    // ******************************************************************************************
    // EVENTS
    // ******************************************************************************************

    /// @notice Emitted when a new country is minted.
    /// @param owner the owner of the country.
    /// @param countryId the country id.
    /// @param uri the uri.
    event CountryMinted(address owner, uint256 countryId, string uri);

    /// @notice Emitted when a new charity address is set.
    /// @param oldCharity old charity address.
    /// @param newCharity new charity address
    event SetCharityAddress(address oldCharity, address newCharity);

    /// @notice Emitted when a new team address is set.
    /// @param oldTeam old team address.
    /// @param newTeam new team address
    event SetTeamAddress(address oldTeam, address newTeam);

    /// @notice Emitted when a new EarthmetaCity address is set.
    /// @param oldEarthmetaCity old EarthmetaCity address.
    /// @param newEarthmetaCity new EarthmetaCity address
    event SetEarthmetaCity(address oldEarthmetaCity, address newEarthmetaCity);

    /// @notice Emitted when a new EarthmetaCountry address is set.
    /// @param oldEarthmetaCountry old EarthmetaCountry address.
    /// @param newEarthmetaCountry new EarthmetaCountry address
    event SetEarthmetaCountry(address oldEarthmetaCountry, address newEarthmetaCountry);

    /// @notice Emitted when a new EarthmetaLand address is set.
    /// @param oldEarthmetaLand old EarthmetaLand address.
    /// @param newEarthmetaLand new EarthmetaLand address
    event SetEarthmetaLand(address oldEarthmetaLand, address newEarthmetaLand);

    /// @notice Emitted when a new EarthmetaMarketplace address is set.
    /// @param oldEarthmetaMarketplace old EarthmetaMarketplace address.
    /// @param newEarthmetaMarketplace new EarthmetaMarketplace address
    event SetEarthmetaMarketplace(address oldEarthmetaMarketplace, address newEarthmetaMarketplace);

    /// @notice Emitted when a new fee receiver address is set.
    /// @param oldFeeReceiver old fee receiver address.
    /// @param newFeeReceiver new fee receiver address
    event SetFeeReceiver(address oldFeeReceiver, address newFeeReceiver);

    /// @notice Emitted when a new EarthmetaCountry address is set.
    /// @param receiver the receiver address.
    /// @param cityId the city id.
    /// @param countryId the country id.
    /// @param uri the uri.
    /// @param level the city level.
    /// @param price the city sale price.
    event CityMinted(address receiver, uint256 cityId, uint256 countryId, string uri, uint256 level, uint256 price);

    /// @notice Emitted when a new Earthmetaland address is set.
    /// @param receiver the receiver address.
    /// @param cityId the city id.
    /// @param landId the land id.
    /// @param uri the uri.
    /// @param price the city sale price.
    event LandMinted(address receiver, uint256 landId, uint256 cityId, string uri, uint256 price);

    /// @notice Emitted when city level is updated.
    /// @param receiver the receiver address.
    /// @param cityId the city id.
    /// @param countryId the country id.
    /// @param level the city level.
    event CityLevelUpdate(address receiver, uint256 cityId, uint256 countryId, uint256 level);

    /// @notice Emitted when uri is updated.
    /// @param nftAddress the nft address.
    /// @param cityId the city id.
    /// @param uri the uri.
    event UriUpdated(address nftAddress, uint256 cityId, string uri);

    // ******************************************************************************************
    // Structs
    // ******************************************************************************************

    /// @notice City metadata struct.
    /// @param countryId the country id.
    /// @param level the city level.
    struct CityMetadata {
        uint256 countryId;
        uint256 level;
    }

    /// @notice Country metadata struct.
    /// @param countryId the country id.
    /// @param uri the city uri.
    struct CountryMetadata {
        uint256 countryId;
        string uri;
    }

    struct UpdateCityLevel {
        uint256 cityId;
        uint256 countryId;
        uint256 level;
        uint256 oldLevel;
    }

    struct UpdateUri {
        address nftAddress;
        uint256 tokenId;
        string uri;
    }

    struct DeleteToken {
        address nftAddress;
        uint256 tokenId;
    }

    // ******************************************************************************************
    // Functions
    // ******************************************************************************************

    /// @notice a hook function called after a city is transfered. Only EarthmetaCity can call this function.
    /// @param from the city sender.
    /// @param to the city receiver.
    /// @param cityId the city id.
    function afterCityTransfer(address from, address to, uint256 cityId) external;

    /// @notice Update the charity address. Only admin can call this function.
    /// @param _newCharity the new charity address.
    function setCharityAddress(address _newCharity) external;

    /// @notice Update the team address. Only admin can call this function.
    /// @param _newTeam the new team address.
    function setTeamAddress(address _newTeam) external;

    /// @notice Allows to mint a new city. Only the TokenGatway can call this function.
    /// @param receiver the receiver of the minted city.
    /// @param cityId the city id.
    /// @param countryId the country id.
    /// @param uri the token uri.
    /// @param level the level of the city.
    /// @param price the city's purchase price.
    function mintCity(
        address receiver,
        uint256 cityId,
        uint256 countryId,
        string memory uri,
        uint256 level,
        uint256 price
    ) external;

    /// @notice Allows to mint a new countries. Only address with `MINT_COUNTRY` role can call this function.
    /// @param countriesMetadata countries metadata
    function mintCountryBatch(CountryMetadata[] memory countriesMetadata) external;

    /// @notice Returns the amount of royalty.
    /// @param _cityId The city id.
    /// @param _price the sale price.
    /// @return receivers a list of receivers' addresses (charity, team, president)
    /// @return fees a list that contains the amount of fees per address.
    /// @return totalFees the total fees to pay.
    function getRoyaltyCityMetadata(
        uint256 _cityId,
        uint256 _price
    ) external view returns (address[] memory receivers, uint256[] memory fees, uint256 totalFees);

    /// @notice Returns the president metadata of a country.
    /// @param _countryId th country id.
    /// @return president the president address of the country.
    /// @return presidentLevel the president level in the country.
    function getPresident(uint256 _countryId) external view returns (address president, uint256 presidentLevel);

    /// @notice Update the EarthmetaCountry address. Only admin can call this function.
    /// @param _newEarthmetaCountry the new earthmetaCountry address.
    function setEarthmetaCountry(address _newEarthmetaCountry) external;

    /// @notice Update the EarthmetaCity address. Only admin can call this function.
    /// @param _newEarthmetaCity the new earthmetaCity address.
    function setEarthmetaCity(address _newEarthmetaCity) external;

    /// @notice Allows to mint a new land. Only the TokenGatway can call this function.
    /// @param receiver the receiver of the minted land.
    /// @param landId the land id.
    /// @param cityId the city id.
    /// @param uri the token uri.
    /// @param price the land's purchase price.
    function mintLand(address receiver, uint256 landId, uint256 cityId, string memory uri, uint256 price) external;

    /// @notice a hook function called after a land is transfered. Only EarthmetaLand can call this function.
    /// @param from the land sender.
    /// @param to the land receiver.
    /// @param landId the land id.
    function afterLandTransfer(address from, address to, uint256 landId) external;

    /// @notice Update the EarthmetaLand address. Only admin can call this function.
    /// @param _newEarthmetaLand the new earthmetaLand address.
    function setEarthmetaLand(address _newEarthmetaLand) external;

    /// @notice Returns the amount of royalty.
    /// @param _landId The city id.
    /// @param _price the sale price.
    /// @return receivers a list of receivers' addresses (charity, team, president)
    /// @return fees a list that contains the amount of fees per address.
    /// @return totalFees the total fees to pay.
    function getRoyaltyLandMetadata(
        uint256 _landId,
        uint256 _price
    ) external view returns (address[] memory receivers, uint256[] memory fees, uint256 totalFees);

    /// @notice Returns the amount of royalty.
    /// @param _nftAddress The nft address.
    /// @param _cityId The city id.
    /// @param _price the sale price.
    /// @return receivers a list of receivers' addresses (charity, team, president)
    /// @return fees a list that contains the amount of fees per address.
    /// @return totalFees the total fees to pay.
    function getRoyaltyMetadata(
        address _nftAddress,
        uint256 _cityId,
        uint256 _price
    ) external view returns (address[] memory receivers, uint256[] memory fees, uint256 totalFees);

    /// @notice Get the marketplace address
    /// @return address The marketplace address.
    function marketplace() external view returns (address);

    /// @notice Set the marketplace address
    /// @param _newEarthmetaMarketplace The marketplace address.
    function setEarthmetaMarketplace(address _newEarthmetaMarketplace) external;

    function feeReceiver() external view returns (address);
}