//
//  RLPDecoder.swift
//  Web3
//
//  Created by Koray Koska on 03.02.18.
//

import Foundation
import VaporBytes

open class RLPDecoder {

    public init() {
    }

    open func decode(_ rlp: Bytes) throws -> RLPItem {
        guard rlp.count > 0 else {
            throw Error.inputEmpty
        }
        let sign = rlp[0]

        if sign >= 0x00 && sign <= 0x7f {
            guard rlp.count == 1 else {
                throw Error.inputBad
            }
            return .bytes(sign)
        } else if sign >= 0x80 && sign <= 0xb7 {
            let count = sign - 0x80
            guard rlp.count == count + 1 else {
                throw Error.inputBad
            }
            let bytes = Array(rlp[1..<rlp.count])
            return .bytes(bytes)
        } else if sign >= 0xb8 && sign <= 0xbf {
            let byteCount = sign - 0xb7
            guard rlp.count >= byteCount + 1 else {
                throw Error.inputBad
            }
            guard byteCount <= 8 else {
                throw Error.inputTooLong
            }

            guard let stringCount = Array(rlp[1 ..< (1 + Int(byteCount))]).bigEndianUInt else {
                throw Error.inputTooLong
            }

            let rlpCount = stringCount + UInt(byteCount) + 1
            guard rlp.count == rlpCount else {
                throw Error.inputBad
            }

            let bytes = Array(rlp[(Int(byteCount) + 1) ..< Int(rlpCount)])
            return .bytes(bytes)
        } else if sign >= 0xc0 && sign <= 0xf7 {
            let totalCount = sign - 0xc0
            guard rlp.count == totalCount + 1 else {
                throw Error.inputBad
            }
            if totalCount == 0 {
                return []
            }
            var items = [RLPItem]()

            var pointer = 1
            while pointer < rlp.count {
                let innerSign = rlp[pointer]
                let count: UInt8
                if innerSign >= 0x00 && innerSign <= 0x7f {
                    count = 1
                } else if innerSign >= 0x80 && innerSign <= 0xb7 {
                    count = innerSign - 0x80
                } else if innerSign >= 0xc0 && innerSign <= 0xf7 {
                    count = innerSign - 0xc0
                } else {
                    // If the whole list ist <= 55 bytes, one item should never be > 55 bytes.
                    throw Error.inputBad
                }

                guard rlp.count >= (pointer + Int(count) + 1) else {
                    throw Error.inputBad
                }

                let itemRLP = Array(rlp[pointer..<(pointer + Int(count) + 1)])
                try items.append(decode(itemRLP))

                pointer += (Int(count) + 1)
            }

            return .array(items)
        } else if sign >= 0xf8 && sign <= 0xff {
            let byteCount = sign - 0xf7
            guard rlp.count >= byteCount + 1 else {
                throw Error.inputBad
            }
            guard byteCount <= 8 else {
                throw Error.inputTooLong
            }

            guard let totalCount = Array(rlp[1 ..< (1 + Int(byteCount))]).bigEndianUInt else {
                throw Error.inputTooLong
            }

            let rlpCount = totalCount + UInt(byteCount) + 1
            guard rlp.count == rlpCount else {
                throw Error.inputBad
            }
            var items = [RLPItem]()

            var pointer = 1
            while pointer < rlp.count {
                let count = try getCount(rlp: Array(rlp[pointer...]))

                guard rlp.count >= (pointer + count + 1) else {
                    throw Error.inputBad
                }

                let itemRLP = Array(rlp[pointer..<(pointer + count + 1)])
                try items.append(decode(itemRLP))

                pointer += (count + 1)
            }

            return .array(items)
        } else {
            throw Error.lengthPrefixBad
        }
    }

    public enum Error: Swift.Error {

        case inputEmpty
        case inputBad
        case inputTooLong

        case lengthPrefixBad
    }

    private func getCount(rlp: Bytes) throws -> Int {
        guard rlp.count > 0 else {
            throw Error.inputBad
        }
        let sign = rlp[0]
        let count: UInt
        if sign >= 0x00 && sign <= 0x7f {
            count = 1
        } else if sign >= 0x80 && sign <= 0xb7 {
            count = UInt(sign) - UInt(0x80)
        } else if sign >= 0xb8 && sign <= 0xbf {
            let byteCount = sign - 0xb7
            guard rlp.count >= (Int(byteCount) + 1) else {
                throw Error.inputBad
            }
            guard let c = Array(rlp[1..<(Int(byteCount) + 1)]).bigEndianUInt else {
                throw Error.inputTooLong
            }
            count = c
        } else if sign >= 0xc0 && sign <= 0xf7 {
            count = UInt(sign) - UInt(0xc0)
        } else if sign >= 0xf8 && sign <= 0xff {
            let byteCount = sign - 0xf7
            guard rlp.count >= (Int(byteCount) + 1) else {
                throw Error.inputBad
            }
            guard let c = Array(rlp[1..<(Int(byteCount) + 1)]).bigEndianUInt else {
                throw Error.inputTooLong
            }
            count = c
        } else {
            throw Error.lengthPrefixBad
        }

        guard count <= Int.max else {
            throw Error.inputTooLong
        }

        return Int(count)
    }
}
