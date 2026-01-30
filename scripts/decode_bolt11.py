#!/usr/bin/env python3
"""
Minimal BOLT11 invoice decoder - no external dependencies.
Decodes enough to display: amount, description, expiry, payee.
"""

import sys
import re
from hashlib import sha256

CHARSET = "qpzry9x8gf2tvdw0s3jn54khce6mua7l"

def bech32_decode(bech):
    """Decode bech32 string, return (hrp, data) or (None, None)."""
    if any(ord(c) < 33 or ord(c) > 126 for c in bech):
        return None, None
    bech = bech.lower()
    if bech != bech.lower() and bech != bech.upper():
        return None, None
    if '1' not in bech:
        return None, None
    pos = bech.rfind('1')
    if pos < 1 or pos + 7 > len(bech):
        return None, None
    hrp = bech[:pos]
    data = [CHARSET.find(c) for c in bech[pos+1:]]
    if -1 in data:
        return None, None
    return hrp, data[:-6]  # strip checksum

def convert_bits(data, frombits, tobits, pad=True):
    """Convert between bit sizes."""
    acc, bits, ret = 0, 0, []
    maxv = (1 << tobits) - 1
    for value in data:
        acc = (acc << frombits) | value
        bits += frombits
        while bits >= tobits:
            bits -= tobits
            ret.append((acc >> bits) & maxv)
    if pad and bits:
        ret.append((acc << (tobits - bits)) & maxv)
    return ret

def parse_amount(hrp):
    """Parse amount from HRP like 'lnbc100u' -> 10000 sats."""
    match = re.match(r'ln(bc|tb|bcrt)(\d+)([munp])?', hrp)
    if not match:
        return None
    
    amount_str, multiplier = match.group(2), match.group(3)
    if not amount_str:
        return None
    
    amount = int(amount_str)
    mult_map = {'m': 100000, 'u': 100, 'n': 0.1, 'p': 0.0001, None: 100000000}
    sats = int(amount * mult_map.get(multiplier, 100000000))
    return sats

def parse_tagged_fields(data_5bit):
    """Parse tagged fields from 5-bit data."""
    data_8bit = bytes(convert_bits(data_5bit, 5, 8, pad=False))
    
    fields = {}
    pos = 7 + 1  # skip timestamp (7 bytes) + recovery flag
    
    # Actually, let's parse from 5-bit directly
    pos = 7  # timestamp is 7 x 5-bit values
    data = data_5bit[pos:]
    
    while len(data) >= 3:
        tag = data[0]
        data_len = data[1] * 32 + data[2]
        if len(data) < 3 + data_len:
            break
        tag_data = data[3:3+data_len]
        data = data[3+data_len:]
        
        if tag == 13:  # 'd' = description
            desc_bytes = bytes(convert_bits(tag_data, 5, 8, pad=False))
            try:
                fields['description'] = desc_bytes.decode('utf-8')
            except:
                pass
        elif tag == 6:  # 'x' = expiry
            expiry = 0
            for v in tag_data:
                expiry = expiry * 32 + v
            fields['expiry'] = expiry
        elif tag == 1:  # 'p' = payment hash
            ph_bytes = bytes(convert_bits(tag_data, 5, 8, pad=False))
            fields['payment_hash'] = ph_bytes.hex()[:16] + '...'
        elif tag == 19:  # 'n' = payee pubkey
            pk_bytes = bytes(convert_bits(tag_data, 5, 8, pad=False))
            if len(pk_bytes) == 33:
                fields['payee'] = pk_bytes.hex()
    
    return fields

def decode_invoice(invoice):
    """Decode BOLT11 invoice and return dict."""
    invoice = invoice.strip().lower()
    
    hrp, data = bech32_decode(invoice)
    if not hrp or not data:
        return None
    
    result = {}
    
    # Network
    if hrp.startswith('lnbc'):
        result['network'] = 'mainnet'
    elif hrp.startswith('lntb'):
        result['network'] = 'testnet'
    elif hrp.startswith('lnbcrt'):
        result['network'] = 'regtest'
    else:
        return None
    
    # Amount from HRP
    amount = parse_amount(hrp)
    if amount is not None:
        result['amount_sats'] = amount
    
    # Tagged fields
    try:
        fields = parse_tagged_fields(data)
        result.update(fields)
    except:
        pass
    
    return result

def format_amount(sats):
    """Format sats with commas."""
    return f"{sats:,}"

def main():
    if len(sys.argv) < 2:
        print("Usage: decode_bolt11.py <invoice>", file=sys.stderr)
        sys.exit(1)
    
    invoice = sys.argv[1]
    result = decode_invoice(invoice)
    
    if not result:
        # Fallback: just show truncated
        print(f"[Invoice: {invoice[:20]}...{invoice[-10:]}]")
        sys.exit(0)
    
    print()
    print("⚡ Lightning Invoice")
    if 'amount_sats' in result:
        print(f"   Amount: {format_amount(result['amount_sats'])} sats")
    if 'description' in result:
        desc = result['description'][:50]
        if len(result['description']) > 50:
            desc += '...'
        print(f"   Memo: \"{desc}\"")
    if 'expiry' in result:
        print(f"   Expiry: {result['expiry']}s")
    if 'payee' in result:
        pk = result['payee']
        print(f"   Payee: {pk[:12]}...{pk[-8:]}")
    print(f"   [{invoice[:15]}...] 📋")
    print()

if __name__ == '__main__':
    main()
