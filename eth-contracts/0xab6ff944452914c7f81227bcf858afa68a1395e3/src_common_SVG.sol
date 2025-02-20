//SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "./src_common_Utils.sol";

// Core SVG utilitiy library which helps us construct
// onchain SVG's with a simple, web-like API.
library Svg {
    using Utils for uint256;

    /* MAIN ELEMENTS */
    function svg(string memory _props, string memory _children) internal pure returns (string memory) {
        return el('svg', _props, _children);
    }

    function g(string memory _props, string memory _children) internal pure returns (string memory) {
        return el('g', _props, _children);
    }

    function symbol(string memory _props, string memory _children) internal pure returns (string memory) {
        return el('symbol', _props, _children);
    }

    function mask(string memory _props, string memory _children) internal pure returns (string memory) {
        return el('mask', _props, _children);
    }

    function defs(string memory _props, string memory _children) internal pure returns (string memory) {
        return el('defs', _props, _children);
    }

    function use(string memory _props, string memory _children) internal pure returns (string memory) {
        return el('use', _props, _children);
    }

    function path(string memory _props, string memory _children) internal pure returns (string memory) {
        return el('path', _props, _children);
    }

    function text(string memory _props, string memory _children) internal pure returns (string memory) {
        return el('text', _props, _children);
    }

    function line(string memory _props, string memory _children) internal pure returns (string memory) {
        return el('line', _props, _children);
    }

    function circle(string memory _props, string memory _children) internal pure returns (string memory) {
        return el('circle', _props, _children);
    }

    function circle(string memory _props) internal pure returns (string memory) {
        return el('circle', _props);
    }

    function rect(string memory _props, string memory _children) internal pure returns (string memory) {
        return el('rect', _props, _children);
    }

    function rect(string memory _props) internal pure returns (string memory) {
        return el('rect', _props);
    }

    function filter(string memory _props, string memory _children) internal pure returns (string memory) {
        return el('filter', _props, _children);
    }

    function feColorMatrix(string memory _props) internal pure returns (string memory) {
        return el('feColorMatrix', _props);
    }

    function cdata(string memory _content) internal pure returns (string memory) {
        return string.concat('<![CDATA[', _content, ']]>');
    }

    /* GRADIENTS */
    function radialGradient(string memory _props, string memory _children) internal pure returns (string memory) {
        return el('radialGradient', _props, _children);
    }

    function linearGradient(string memory _props, string memory _children) internal pure returns (string memory) {
        return el('linearGradient', _props, _children);
    }

    function gradientStop(string memory offset, string memory stopColor, string memory _props) internal pure returns (string memory) {
        return
            el(
                'stop',
                string.concat(
                    prop('stop-color', stopColor),
                    ' ',
                    prop('offset', string.concat(offset, '%')),
                    ' ',
                    _props
                )
            );
    }

    function animateTransform(string memory _props) internal pure returns (string memory) {
        return el('animateTransform', _props);
    }

    function image(string memory _href, string memory _props) internal pure returns (string memory) {
        return
            el(
                'image',
                string.concat(prop('href', _href), ' ', _props)
            );
    }

    /* COMMON */
    // A generic element, can be used to construct any SVG (or HTML) element
    function el(bytes32 _tag, string memory _props, string memory _children) internal pure returns (string memory) {
        string memory strTag = Utils.toString(_tag);
        
        return
            string.concat(
                '<',
                strTag,
                ' ',
                _props,
                '>',
                _children,
                '</',
                strTag,
                '>'
            );
    }


    // A generic element, can be used to construct any SVG (or HTML) element without children
    function el(bytes32 _tag, string memory _props) internal pure returns (string memory) {
        return el(_tag, _props, "");
    }

    // an SVG attribute
    function prop(bytes32 _key, string memory _val) internal pure returns (string memory) {
        return string.concat(Utils.toString(_key), '=', '"', _val, '" ');
    }
}