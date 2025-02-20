// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./node_modules_openzeppelin_contracts_token_ERC1155_ERC1155.sol";
import "./node_modules_openzeppelin_contracts_access_Ownable.sol";
import "./node_modules_openzeppelin_contracts_utils_Strings.sol";
import "./node_modules_openzeppelin_contracts_utils_Base64.sol";

contract RADMNFT is ERC1155, Ownable(msg.sender) {
    using Strings for uint256;
    
    string public constant name = "RadmantisNFT";
    string public constant symbol = "RADM";
    uint256 private _tokenIdCounter;
    uint256 public constant MAX_SUPPLY = 10;
    
    // Track minted tokens
    mapping(uint256 => bool) private _tokenMinted;
    
    // string private constant IMAGE_DATA = "data:image/gif;base64,R0lGODlhgAB8AMZ1AD -'truncated'";
    // string private constant THUMBNAIL_DATA = "data:image/gif;base64,R0lGODlhIAAfAMZ0AD -'truncated'";
    string private constant IMAGE_DATA = "data:image/gif;base64,R0lGODlhsgAAAef+ABgN8BQh7xgi8B8k8yUp7yss8hwx8y4w7TAx7jIy7zQz8Sg48jY08io58zg47To57jw68D078TM/8j888jVA80JA70RB8DtF8UVC8TxG8kdD8j5H80lH70tI8ExJ8URN8kdP9FBO71FP8FJQ8VRR8ktU8kxV81VV71hX8VpY8lxd8F1e8V5f8mBg82Fh9Gdg72Fk8GJl8WNm8mRn82tn725p8Wlt83Bv73Jw8XNx8m519HV28Hd48oB78IF88nt/8n2A9H6B9YSC8YaE84eF9IiG9YeJ8IiK8omL84qM9IuN9YyO9pKP8pOR9JWS9QDNaY+V9gPMcJSW8RLLaQjOcZaY9BXMapiZ9Q7PchLQc56b8qCd8yzMcSbOeaGe9SjPei7Ocpyh9i/PcyrQe6Gi8izRfKKj86Ok9D3Pe6Wm9j/QfEDRfULSfqyp9EvRhE/RfkzSha2r9U7Thq+t96mv+K2v81rShlfTjlvTiFzUiWPTj7Gz9mTUkLK097O1+GXWkbe283DVkri39XHXk2/YmnLYlHjXm727+XnYnHzYlXrZncG89XvanoPZnr3A9oXan77B+L/C+YTcp4fcocDE+o3cqMXF9o7dqcbG94/eq8jI+pjerMnJ+5nfrZrgrsrL/J/ftKDgtc/M96HhttHO+aPjuNLP+qriuKvjutDT9qzku9LU+LHkwqvmwtPV+bLlw9TW+rXlvbTmxNbY/LXnxdrZ97znxrbpx9va+L3oyNzb+b/pyd3c+97d/MDry8Xq0d/f/cbr0uDg/sfs0+Th+cjt1OXi+tDs1ubj+9Hu1+Hm/NLv2OLn/dPw2ePo/9Tx2ufp+ujq+9nx4enr/Nry4+rs/dvz5Nz05ezt/uPy5eTz5t715u3v/+X05+7w//Dw+ub26PHx++f36fLy/O726+b48ej46/Pz/u338u/37Of58vX0/+748/b1//n2++/69Pr3/PD79fv4/fj69/L89/n7+PP9+Pz6/vr8+f77//v9+vr///z/+/3//P///////yH5BAEKAP8ALAAAAACyAAABAAj+APkJHEiwoMGDCBMqXMiwocOHECMSxEeP3L9/UTJqjHKxo0eJIEOKHEmy5MF64mxZ2chyIxePF03KnEmzZkRxwVrq1PnRps+fQEkG6wRnp1GWHYMqXcq0oL5YfI5KRfqvqdWrM/WV+6eGy9SvGWNiHUsWYjeMYNOGLcu2rcFtk56onVvVrV2y9TbN3cvxrt+m+mQV5TuXy9/DQKlx8Up4L+LHM9FVatwYsuWRw9RQJmz4sueH8wJtpvy59EJ0bkaTNs164r8uqle3Zk1PUmzKnWeXjvfo9mbdpf+J9t24LnDL/xgTJyztuOVbyze/c/44V/TN8agfpnV98zztftH+dm+MD7zd5OMbBzLv9t3w9Hybsy/7jhH8xtvmk7XX+z5fK93oN1Z//u1lBToCXiVegXOpUU+CTZGTGoN7oQIhU/HoQSFfvly4FCEb8nWMh0FREyJf+ZHo0zvKnQgWGw+qaNOCLn4Fiow2WdNijVO9gmNNUfEIFh4x/mhSLl8ICZYhRsqEjyJKfvVSkyadEuVXauhDJUnoTHHlVMZtGdJkX0qFoJghxVOmVHhoiSZINK65EYBvgqSPZnLqVEmdIO2yY54ZacOnRO8BmhEXowwaUTKwGaoRH4pGdImjG40YqUPiUKrRJZc+NIymUVjBTqcN6YMHqM1IlI8764zjDTb+2IQzTjvu5COjOCtRKktE7hijxQMVWGABBhhYUEEFFIigCzPj7HPhMZrCQQ9EukjQgAUZZKvtthk8wEAAfczijoD4yOWoGgE+ZEoJ3LbbbgUPpEAHNvOp6SgXKToEiwnu9tsuBjEM8U8+zlIX55phMoQNBv423O4GKTiyjq3H2eEoH+U5lA8mDzjs8bYYIEBJNAXP9oahfGT3UDsGfOyytg9IsIUxs4kzBqB4nPnQPwy/7LMFHTjRDmuT5slGOhL94/PS2WJgQxj3lGyZfXmqAxLTWGewgQic3ONZoV8m/FDWWVcggDDI5Sn22GSXHcm4iNkiZycjtU12BTAgg5j+lWWuDZEGdmeNwQr/eO1XJ32XdEHgbcMQzl3vJF4S43bXoLdb2XxJt0lKUy74BntQXFYzV/oNp+dtUyCF6GN9KuSUM3FTAeptD2H4WLsICYfpIY0jAe1tFwH3Vfrk6iIe4tjUTsfAZ20BE+tgRY/xIfKRvE3uMN881hIsEb1V7FBPoR0615RP59tjXYEQwy+F64nSArXPGdimn3UPtyvVTYhs/JMxULpogP3IloT8AUUbG3pDqpZiDAYMsGxXMKBPMscgNVijKdFQwAOz9oAwsM4nr6AQ0poSjgNsMGsSIIXUZlSgYfyPKfmAQc9OuLQRPA4oB1uOGpJBlkj8job+TItB+2iijxz6JhDpGgsnfghEn2HgBx+UiT7SYwVZuIkssNBeE18mAU34BB/psRRblMHELbpscNOwCRijw4VKFIkt+bCBGZnmAQmSpB7R4QPvsHKGGc7xYxKoxQrvuBxGqMwvgPDjHz1GAW7QBI+3gcMyrugXd9RgkT7zwSNvs4byHSYImHyZB2AxE0hu5gvboCRiLMGBULrMCVEMiSkJM4ZLTMsz+UiBKz/2AFPIZJZ78cQzTHO+XXoMA0oYWkmAmZYp5GI20SijMd2lAF2YhJlT4UInDsmae7BAkdMEmRBLssa04GE6xxGGBsPZLwnQjCRTTEsgbnmceygBnOz+zJYIYgmReH4FEdw8ziy0mE9teaAWJTHiRgIR0OPs4woFddcPEjoVODTUOfeIQUS55YE9MuQZUuGCoPSziFZutGlzIMk2pOJR3eTjpNti30gQaJROqJI9xFjnSXs5kv3txArXS1A+NEHQfGIgB/xsyPtawgVakKgduoRpAugVEnLsRBEyUsYKYPqAVYjkHeKLwhjko6JaRHWjArBjQ+bhJZa4wUjoiygFvgeSU7EkqDJyx1Y3ioGWIkRuG/HrfMIxA3wacwZJVQg+WkQnKkEDB4Z15QoSmxBpsMQK6KQSJygQURGkMSL6aKtGgCqmfcSVnVdImk4sJKZiFrQIErH+a0te2KR7GKF+4eTBIBVSj5PpJLNbcgcTOBtOCwiWH0XjSZ3akQTc7hIDhwCNbFtiBz614wfhxEAbHuKLo4whX2hyxw6miYHUOqQUUuEUn9wBhNntkgJUXYhPj7KeQa0jCcQN5QOsyZBifCUYimoHEiILxAekgiH4QMRXGBEpd2BXv148TVh10thB3cMHBN7g4ChL0/9e6h5McO8fCzBEp+AJLBdFUz628IAM2w8BN0RIPf50FB5eKh+mGMEfFRDfg2yDxke5KZ+iwS8zMoAZClGoTmDXKW+0wMXAa8A7EaKhueiBVAIZhw6gjLoGEEMhg1GLGkaF5Xv0QIA0lAD+J3bLj9fwRRJYFkg+ZiHiDQ4MIXzbCxySSKp9MIPLjLvzQfRCmM3FmR/j+IEINmgBtU6CMhc8tEAi4YEHYkCtYJvLGITcKVgcQJq0s0CJ+bHSzZBV0uEARFE9J+qDQGs0nO5UPixR6eZhYNS52wyTJc0P0wIB0C+zgDILwp3R2IG2ks5HGhQAbI8J+yCtiM0meG0QYhCh2Q3DwLAJoorYvIHP1OaHO/5R57Zp2yD6yLR6Yh3nfHCDBSEI3LMLEo8JN+bU4RbIPlyRAmyDbNsCQQdxvkDmfBPkG3UIluAAzo9MEUcNBj+ILpyw6mMyfL63+cIwI16Qe0Qivy87d0H+MH6bMniS4/twhxKWdmuDdJg4huY4Qc4XAi63uiAvJ06HZG6QVdQAyi3H+XjwzXN+wOKsDWu0y8fzhDcWvc0fU7rQxxPzp5vWY4ImCMmXg6inz9wJ5eZW1gfi8PQc99DtAHu/LGCGQS41PeB9ujAS0K/9HiR893lEiiO+jzng08sHsdd9EOF0nt8jB+5qwOVMXKBAIFvmnABBuxgADYSggkGMeDzf97qtqSKEFRRyo9f5gQxFImAcCCk2gy6h+XznY9HbIjFCck2hR7Cb2shwoLYKoFb/higRhTe4OwqwLQZEAyHWcJEi6Mnx4W+rAnSIpalc9AjgGjyD3JIAwwX+8mjqLzDimgB5tryw2+S66Ox1uofk27UCO4bidaFofafG4dxtkeEgSi7QJk7eZ0cYFgcS9A4nxiNPMAy8lg8u4C8VwAkHMV1CEgrWdyn/0AH+ggEpZRBBciVqQA1xBlENUwGfRRD5pxpcEAiJoAiM8AgqqIKMoAiIEAh48gX/EIHpN14N8wCuYBDkAGSjEQqtkAvH0FLs0Ay/QAuq8EyXYglhxy0V4EEFMWO+oQjHQA38Z3U54GIF4EgEoQ88OBfSgA63V3TEUHHc8gBTNhAjaBRcgAfSIH+jtw+RQIbckgIfVHZ7kQjoJ3PjMAAvwwFDFA+ilRZWAAphOHq9Rgn+S9gvG3CGAnF5asEHcWeICXEP9Yd1BkE65kSDkoh/TIMDK7R1RnEH37GJDLEPcrQ0LRBFDrgT80SKDRENSHdGYmMdUhEIBeeKCsEE/rZd9LaKLGFjuKgQZpU15lUQBMJU6hWMCZEP95Q1R3AQsgBkb1CIrpgKcugwFbA2YYYUyqgQ7gAAbVMBs3AQckBhboiL+4AJiegyC3gQoAiM3WgQ91Brd+MIJ9EoG6GJ8Xha6gMICPELLLEL8YgQ4wAD8pYGCNElG/F9A0kQQeBv7UICajUKG2E1DUkQsLCOS5MAqOdjGgFnFzkQ7SBDlMMAIWgQnpARrBWS+2AK1+gzR5b+EM9wM0gYksjwkjDJiAUBJXnIc/lAgV2GNgnRDXhgDyHJDyVFOw3AXwkRCkeJC+vXZUx5lAiRD07QPEtJlcs4B6DGOFmplQYBh2gWZbgAlgYxDrqHlVNplmYGkby0llqZD0QwQF9plvngBW7pMg0glGDZdzhpN1JmlvzADCb0QDEJlt/wAnn5MjyGmCxAQwoQYyHJDTgARA0wat2IDTywmE6kBVT5DTlQifZTAX5wlOFAkkBUAdF1kdiQgFtUAZhwkcIAWWZUAaQUj+eTAJyJQj0ZbvlwBRr5QEMQj+4wBKHkBMq4D9hQBK7kBcGYD4tAALsZOHSAi/9ABn9pZ6T+2JIgMJ2MEwOUlW/KuQIeQCzmeZ7oeZ4D5ImGuA/GAAAJ4ARn0AZ+cAiRoAmiQAoXYQqaEAmL4AdtcAZCwAAPACzN05uXsg+6YAzfoCrRUAucUAcBwADeuQGLJ5gFsQ/jwAzktpt+iKEKsSrG0AJRmTUcoFYgShCmNWD+1lfhmaK9JgpLkJ3a0gDHB6MO0Q5eEJztUgCSiaMLcT4b8DIVYAYvCqT65g3fxEsHhqQQgQ206TALoAxOGhG6QHfZBgRHWqX6lgaiqS0WAAlcGhH5wJwViKBAqlf+ggRjKhH70Af9wgH+2Ka8olPbkgIoSqcIsQ+iUFT/wGZ6mhDcQFBUGNBjgeoQcbgtUneoD+EK2mNcgMqoB4EN2iMAPyqpDAEFDEMBgBCpmGoQfcAwFUCln/oQmEAsvFiqDhENI5ACF6qqDJEDzwirD5EEDUqrDvGnpBIQADs=";
    string private constant THUMBNAIL_DATA = "data:image/gif;base64,R0lGODlhFgAgAOf9ABgN8BQh7xgi8B8k8yUp7yss8hwx8y4w7TAx7jIy7zQz8Sg48jY08io58zg47To57jw68D078TM/8j888jVA80JA70RB8DtF8UVC8TxG8kdD8j5H80lH70tI8ExJ8URN8kdP9FBO71FP8FJQ8VRR8ktU8kxV81VV71hX8VpY8lxd8F1e8V5f8mBg82Fh9Gdg72Fk8GJl8WNm8mRn82tn725p8Wlt83Bv73Jw8XNx8m519HV28Hd48oB78IF88nt/8n2A9H6B9YSC8YaE84eF9IiG9YeJ8IiK8omL84qM9IuN9YyO9pKP8pOR9JWS9QDNaY+V9gPMcJSW8RLLaQjOcZaY9BXMapiZ9Q7PchLQc56b8qCd8yzMcSbOeaGe9SjPei7Ocpyh9i/PcyrQe6Gi8izRfKKj86Ok9D3Pe6Wm9j/QfEDRfULSfqyp9EvRhE/RfkzSha2r9U7Thq+t96mv+K2v81rShlfTjlvTiFzUiWPTj7Gz9mTUkLK097O1+GXWkbe283DVkri39XHXk2/YmnLYlHjXm727+XnYnHzYlXrZncG89XvanoPZnr3A9oXan77B+L/C+YTcp4fcocDE+o3cqMXF9o7dqcbG94/eq8jI+pjerMnJ+5nfrZrgrsrL/J/ftKDgtc/M96HhttHO+aPjuNLP+qriuKvjutDT9qzku9LU+LHkwqvmwtPV+bLlw9TW+rXlvbTmxNbY/LXnxdrZ97znxrbpx9va+L3oyNzb+b/pyd3c+97d/MDry8Xq0d/f/cbr0uDg/sfs0+Th+cjt1OXi+tDs1ubj+9Hu1+Hm/NLv2OLn/dPw2ePo/9Tx2ufp+ujq+9nx4enr/Nry4+rs/dvz5Nz05ezt/uPy5eTz5t715u3v/+X05+7w//Dw+ub26PHx++f36fLy/O726+b48ej46/Pz/u338u/37Of58vX0/+748/b1//n2++/69Pr3/PD79fv4/fj69/L89/n7+PP9+Pz6/vr8+f77//v9+vr///z/+////////////yH5BAEKAP8ALAAAAAAWACAAAAj+APkJHEiwoEB6tvhEiWKw4cBgbBYudNgQlMSFbigWVHVxYSONA6l1XKgKpEBDI7OIc0esGsVtI6Og4gckQ4YhsBrKGokIHz+bQKWMK9ioYyB6AnkAtckjHME8FxshFXhlqU0iPgViWUhFVVaBmKzatCRQ30I+1Ay2YyEWRlYxj+o5XCU2gyuBfNJpFCS2Db90bL463GMVCD9bUZaZtPQBqAp+RRWZ5AfMhs0L+twsfDbZ3Z4NF/BJ1GNvMr9DJ8xK7GQa3w9+di6emjzuQ6+iC9EEQlVao6UMcXbieaZvMj4dGXR062LONL/fGUDoY+W82onL+ARrdKfU5obik8MfBVlqw3S7SILOqLBZxflAd2EyYHI/sN4Mp/QF5gQZEAA7"; 

    constructor() ERC1155("") {}

    // function mint(address to) public onlyOwner {
    //     require(_tokenIdCounter < MAX_SUPPLY, "All tokens have been minted");
    //     require(!_tokenMinted[_tokenIdCounter], "Token already minted");
        
    //     _mint(to, _tokenIdCounter, 1, "");
    //     _tokenMinted[_tokenIdCounter] = true;
    //     _tokenIdCounter++;
    // }

    function safeMint(address to, uint256 id, bytes memory data) public onlyOwner {
        require(id <= MAX_SUPPLY, "Invalid token ID");
        require(!_tokenMinted[id], "Token already minted");
        require(_tokenIdCounter < MAX_SUPPLY, "All tokens have been minted");
        
        _mint(to, id, 1, data);
        _tokenMinted[id] = true;
        _tokenIdCounter++;
    }

    function uri(uint256 tokenId) public view virtual override returns (string memory) {
        require(tokenId <= MAX_SUPPLY, "Invalid token ID");
        require(_tokenMinted[tokenId], "Token has not been minted");

        string memory json = Base64.encode(bytes(abi.encodePacked(
            '{"name": "Radmantis #',
            tokenId.toString(),
            '",',
            '"description": "Celebrating the first seven years of efforts at Radmantis up to 1/1/25 with Moira van Staaden, Robert Huber, Scott Hall, Sebastian Huber, Chris Kemp and Joe Konecny",',
            '"image": "', IMAGE_DATA, '",',
            '"thumbnail": "', THUMBNAIL_DATA, '",',
            '"attributes": [',
            '{"trait_type": "Edition", "value": "', tokenId.toString(), '"}',
            ']',
            '}'
        )));
        
        return string(abi.encodePacked("data:application/json;base64,", json));
    }

    function totalSupply() public view returns (uint256) {
        return _tokenIdCounter;
    }
}