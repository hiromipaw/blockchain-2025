// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * Determinism & Oracle demo:
 * - "Oracle" posts a price on-chain (stand-in for a real network).
 * - Consumer reads it only if it's fresh and sane.
 */
contract SimpleOracle {
    address public immutable poster;      // who is allowed to post (simulate an oracle)
    uint256 public price;                 // e.g., ETH/USD * 1e8
    uint256 public lastUpdated;           // unix time of last post

    event Posted(uint256 price, uint256 at);

    constructor(address _poster) {
        require(_poster != address(0), "poster required");
        poster = _poster;
    }

    function postPrice(uint256 newPrice) external {
        require(msg.sender == poster, "only poster");
        require(newPrice > 0, "bad price");
        price = newPrice;
        lastUpdated = block.timestamp;
        emit Posted(newPrice, lastUpdated);
    }
}

contract UseSimpleOracle {
    SimpleOracle public oracle;
    uint256 public constant STALE_AFTER = 10 minutes; // freshness guard

    event Acted(uint256 refPrice, uint256 at);

    constructor(address oracleAddr) {
        oracle = SimpleOracle(oracleAddr);
    }

    // Example action that depends on off-chain data brought on-chain
    function doSomethingIfCheap(uint256 maxPrice) external {
        // deterministically read on-chain oracle state
        uint256 p = oracle.price();
        uint256 t = oracle.lastUpdated();
        require(p > 0 && block.timestamp - t <= STALE_AFTER, "stale or missing data");
        require(p <= maxPrice, "too expensive right now");

        emit Acted(p, block.timestamp);
    }
}