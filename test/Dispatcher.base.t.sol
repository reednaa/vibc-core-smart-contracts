// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../contracts/Ibc.sol";
import {Dispatcher, InitClientMsg, UpgradeClientMsg} from "../contracts/Dispatcher.sol";
import {IbcEventsEmitter} from "../contracts/IbcDispatcher.sol";
import {Escrow} from "../contracts/Escrow.sol";
import {IbcReceiver} from "../contracts/IbcReceiver.sol";
import "../contracts/IbcVerifier.sol";
import "../contracts/Verifier.sol";
import "../contracts/Mars.sol";
import "../contracts/OpConsensusStateManager.sol";

// Base contract for testing Dispatcher
contract Base is Test, IbcEventsEmitter {
    uint64 UINT64_MAX = 18446744073709551615;

    ConsensusState untrustedState = ConsensusState(
        80990, 590199110038530808131927832294665177527506259518072095333098842116767351199, 7000040, 1000
    );
    ConsensusState trustedState = ConsensusState(
        10934, 7064503680087416120706887577693908749828198688716609274705703517077803898371, 7002040, 1020
    );
    InitClientMsg initClientMsg = InitClientMsg(bytes("Polymer"), untrustedState);

    ZKMintVerifier verifier = new Verifier();
    ZkProof proof = ZkProof(
        [
            13449388914393258752883032560537386278857542833249142697090243871249761501123,
            5963894333042515966217276339656894890750758020607775733717462915787234629927
        ],
        [
            [
                4811559872397934450173412387101758297072581261546553338353504577141293696514,
                18400634037991283592418145553628778322894277765243742619561207628896194710939
            ],
            [
                17903685207039300384995795331083569887497623740119108595975170464164316221644,
                9246628133289276308945311797896077179503891414159382179119544904154776510385
            ]
        ],
        [
            17432552394458345841788798376121543520587716339044416231610790827968220675517,
            15082220514596158133191868403239442750535261032426474092101151620016661078026
        ]
    );
    Height ZERO_HEIGHT = Height(0, 0);
    uint64 maxTimeout = UINT64_MAX;
    Escrow escrow = new Escrow();

    OptimisticConsensusStateManager opConsensusStateManager = new OptimisticConsensusStateManager(1800, verifier);

    // Proofs from Polymer chain, to verify packet or channel state on Polymer
    Proof emptyProof;
    Proof invalidProof = Proof(Height(0, 42), bytes("")); // invalid proof with empty proof bytes
    Proof validProof = Proof(Height(0, 42), bytes("valid proof"));

    Dispatcher dispatcher;
    string portPrefix = "polyibc.eth.";

    // ⬇️ Utility functions for testing

    // getHexStr converts an address to a hex string without the leading 0x
    function getHexBytes(address addr) internal pure returns (bytes memory) {
        bytes memory addrWithPrefix = abi.encodePacked(vm.toString(addr));
        bytes memory addrWithoutPrefix = new bytes(addrWithPrefix.length - 2);
        for (uint256 i = 0; i < addrWithoutPrefix.length; i++) {
            addrWithoutPrefix[i] = addrWithPrefix[i + 2];
        }
        return addrWithoutPrefix;
    }

    // deriveAddress derives an address from a given string deterministically for testing
    function deriveAddress(string memory str) internal pure returns (address) {
        return vm.addr(uint256(keccak256(abi.encodePacked(str))));
    }

    function mergeFees(PacketFee memory a, PacketFee memory b) internal pure returns (PacketFee memory) {
        return PacketFee(a.recvFee + b.recvFee, a.ackFee + b.ackFee, a.timeoutFee + b.timeoutFee);
    }
}