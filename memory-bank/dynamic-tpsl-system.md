# Dynamic TP/SL Management System

## Overview

The Dynamic Take Profit (TP) and Stop Loss (SL) Management System is a comprehensive feature that enables AI-driven position management on Hyperliquid perpetual contracts. The system allows the AI to:

1. **Set initial TP/SL** when opening new positions
2. **Dynamically update TP/SL** during HOLD operations based on market conditions
3. **Prevent duplicate orders** through intelligent comparison with existing orders
4. **Automatically synchronize** TP/SL orders with the exchange

### Key Features

- **AI-Driven Risk Management**: AI provides exact TP/SL prices in every decision
- **Dynamic Updates**: TP/SL can be adjusted during HOLD operations without closing positions
- **Duplicate Prevention**: 0.1% threshold comparison prevents redundant order creation
- **Multi-Format Support**: Handles various Hyperliquid API response formats
- **In-Memory Cache**: Backup cache for API latency scenarios

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            AI DECISION LAYER                                 │
│  ┌──────────────────┐    ┌──────────────────┐    ┌──────────────────┐       │
│  │  Trading Prompt  │───▶│    AI Model      │───▶│  JSON Decision   │       │
│  │  (alpha_arena)   │    │  (DeepSeek/GPT)  │    │  {tp, sl, op}    │       │
│  └──────────────────┘    └──────────────────┘    └────────┬─────────┘       │
└───────────────────────────────────────────────────────────┼─────────────────┘
                                                            │
                                                            ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                           BACKEND SERVICES                                   │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │                     trading_commands.py                               │   │
│  │  • Parse AI decision                                                  │   │
│  │  • Route to appropriate handler (BUY/SELL/HOLD/CLOSE)                │   │
│  │  • Call update_tpsl() for HOLD with existing position                │   │
│  └──────────────────────────────────────┬───────────────────────────────┘   │
│                                         │                                    │
│                                         ▼                                    │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │                  hyperliquid_trading_client.py                        │   │
│  │  • place_order_with_tpsl() - New positions                           │   │
│  │  • update_tpsl() - Dynamic updates                                    │   │
│  │  • get_tpsl_orders() - Parse existing orders                         │   │
│  │  • cancel_order() - Remove old TP/SL                                 │   │
│  └──────────────────────────────────────┬───────────────────────────────┘   │
│                                         │                                    │
│  ┌──────────────────┐                   │                                    │
│  │  In-Memory Cache │◀──────────────────┤                                    │
│  │  {wallet, symbol}│                   │                                    │
│  │  → {tp, sl, ts}  │                   │                                    │
│  └──────────────────┘                   │                                    │
└─────────────────────────────────────────┼────────────────────────────────────┘
                                          │
                                          ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         HYPERLIQUID EXCHANGE                                 │
│  ┌──────────────────┐    ┌──────────────────┐    ┌──────────────────┐       │
│  │  Hyperliquid API │    │   Open Orders    │    │    Positions     │       │
│  │  (REST + SDK)    │◀──▶│  (TP/SL orders)  │    │  (Long/Short)    │       │
│  └──────────────────┘    └──────────────────┘    └──────────────────┘       │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Components

| Component | File | Responsibility |
|-----------|------|----------------|
| Trading Prompt | `prompts/trading_prompt_alpha_arena.md` | Instructs AI to provide TP/SL values |
| Trading Commands | `backend/services/trading_commands.py` | Orchestrates AI decisions and order execution |
| Hyperliquid Client | `backend/services/hyperliquid_trading_client.py` | Executes orders and manages TP/SL on exchange |
| TPSL Cache | In-memory dict in `hyperliquid_trading_client.py` | Prevents duplicates during API latency |

---

## AI Prompt Integration

### Prompt Requirements

The trading prompt explicitly requires the AI to provide TP/SL values in specific scenarios:

```markdown
=== POSITION MANAGEMENT OUTPUT RULES ===

⚠️ CRITICAL: When you have an EXISTING POSITION, you MUST provide 
stop_loss_price and take_profit_price in the JSON output, even for HOLD operations.

**For HOLD with existing position:**
1. ALWAYS provide stop_loss_price and take_profit_price as exact numeric values
2. If levels should change from current orders → set new values (system will auto-update)
3. If levels should stay the same → copy current TP/SL values from position data
4. NEVER use vague terms like "mental stop" - use exact numbers
```

### JSON Output Format

```json
{
  "operation": "hold",
  "symbol": "SOL",
  "target_portion_of_balance": 0,
  "leverage": 1,
  "stop_loss_price": 125.50,
  "take_profit_price": 135.00,
  "invalidation_condition": "Price closes below $125.50",
  "confidence": 0.6,
  "risk_usd": 0.58,
  "is_add": false,
  "reason": "Holding existing LONG. Tightening SL from $119 to $125.50.",
  "trading_strategy": "MANAGE EXISTING - SHALLOW edge. Risk regime TIGHT."
}
```

---

## Backend Implementation

### Trading Commands Flow

The `place_ai_driven_hyperliquid_order()` function in `trading_commands.py` handles TP/SL in two scenarios:

#### 1. New Position (BUY/SELL)

```python
# Extract TP/SL from AI decision
take_profit_price = decision.get("take_profit_price")
stop_loss_price = decision.get("stop_loss_price")

# Place order with TP/SL
order_result = client.place_order_with_tpsl(
    db=db,
    symbol=symbol,
    is_buy=True,
    size=quantity,
    price=price_to_use,
    leverage=leverage,
    take_profit_price=take_profit_price,
    stop_loss_price=stop_loss_price
)
```

#### 2. HOLD with Existing Position

```python
if operation == "hold":
    # Check if AI provided TP/SL updates
    new_tp = decision.get("take_profit_price")
    new_sl = decision.get("stop_loss_price")
    
    # Find existing position
    position = next((p for p in positions if p.get('coin') == symbol), None)
    
    if position and (new_tp is not None or new_sl is not None):
        # Call update_tpsl to compare and update if needed
        tpsl_result = client.update_tpsl(
            db=db,
            symbol=symbol,
            new_tp_price=new_tp,
            new_sl_price=new_sl,
            position_size=position_size,
            is_long=is_long,
        )
```

---

## Duplicate Prevention System

### Problem Statement

When AI decides "HOLD" with the same TP/SL prices, the system could create duplicate orders on the exchange. This wastes API calls and clutters the order book.

### Solution: Price Comparison with Threshold

```
                         ┌─────────────────────────┐
                         │   update_tpsl() Called  │
                         └───────────┬─────────────┘
                                     │
                                     ▼
                    ┌────────────────────────────────┐
                    │  Fetch Orders from Hyperliquid │
                    │  API (frontend_open_orders)    │
                    └───────────────┬────────────────┘
                                    │
                                    ▼
                    ┌────────────────────────────────┐
                    │  Parse Existing TP/SL Orders   │
                    │  (Multi-format recognition)    │
                    └───────────────┬────────────────┘
                                    │
                                    ▼
                    ┌────────────────────────────────┐
                    │  Compare Prices with Threshold │
                    │  (0.1% = 0.001)                │
                    └───────────────┬────────────────┘
                                    │
              ┌─────────────────────┼─────────────────────┐
              │                     │                     │
              ▼                     ▼                     ▼
    ┌─────────────────┐   ┌─────────────────┐   ┌─────────────────┐
    │  BOTH MATCH     │   │   TP DIFFERS    │   │   SL DIFFERS    │
    │  (diff < 0.1%)  │   │  (diff > 0.1%)  │   │  (diff > 0.1%)  │
    └────────┬────────┘   └────────┬────────┘   └────────┬────────┘
             │                     │                     │
             ▼                     ▼                     ▼
    ┌─────────────────┐   ┌─────────────────┐   ┌─────────────────┐
    │     SKIP        │   │  Cancel Old TP  │   │  Cancel Old SL  │
    │  No API calls   │   │  Create New TP  │   │  Create New SL  │
    └────────┬────────┘   └────────┬────────┘   └────────┬────────┘
             │                     │                     │
             └─────────────────────┼─────────────────────┘
                                   │
                                   ▼
                    ┌────────────────────────────────┐
                    │   Update In-Memory Cache       │
                    │   Return Result                │
                    └────────────────────────────────┘
```

### Implementation Details

```python
# 0.1% threshold to account for rounding differences
PRICE_CHANGE_THRESHOLD_PERCENT = 0.001  # 0.1%

# Check if TP matches existing order
if new_tp_price is not None and current_tp_price is not None:
    tp_diff_percent = abs(current_tp_price - new_tp_price) / current_tp_price
    if tp_diff_percent <= PRICE_CHANGE_THRESHOLD_PERCENT:
        tp_matches_existing = True
        # SKIP - no update needed
```

### Log Output Example

```
[TPSL UPDATE] SOL - API returned: TP=130.0, SL=125.5
[TPSL UPDATE] SOL - Requested: TP=130, SL=125.5
[TPSL UPDATE] SOL TP MATCHES existing: 130.0 ≈ 130 (diff=0.0000%) - SKIP
[TPSL UPDATE] SOL SL MATCHES existing: 125.5 ≈ 125.5 (diff=0.0000%) - SKIP
[TPSL UPDATE] SOL - BOTH TP and SL match existing orders - SKIPPING UPDATE ENTIRELY
```

---

## Order Type Recognition

### Challenge

Hyperliquid API returns order type information in multiple formats depending on the endpoint:

| Format | Source | Example |
|--------|--------|---------|
| Dict | SDK order placement | `{"trigger": {"tpsl": "tp", "triggerPx": 130}}` |
| String | `frontend_open_orders` | `"Take Profit Limit"` or `"Stop Limit"` |
| Condition | Fallback | `"Price above 130"` or `"Price below 125.5"` |

### Solution: Multi-Format Parser

```
                    ┌─────────────────────────┐
                    │      Open Order         │
                    │   from Hyperliquid API  │
                    └───────────┬─────────────┘
                                │
                                ▼
                    ┌─────────────────────────┐
                    │  Is orderType a dict    │
                    │  with 'trigger' key?    │
                    └───────────┬─────────────┘
                                │
              ┌─────────────────┼─────────────────┐
              │ YES             │                 │ NO
              ▼                 │                 ▼
    ┌─────────────────┐         │       ┌─────────────────┐
    │  FORMAT 1: Dict │         │       │  Is orderType   │
    │  Extract from   │         │       │  a string AND   │
    │  trigger.tpsl   │         │       │  isTrigger=true?│
    └────────┬────────┘         │       └────────┬────────┘
             │                  │                │
             │                  │    ┌───────────┼───────────┐
             │                  │    │ YES       │           │ NO
             │                  │    ▼           │           ▼
             │                  │  ┌─────────────────┐  ┌─────────────────┐
             │                  │  │  FORMAT 2:      │  │  Is isTrigger   │
             │                  │  │  String Parse   │  │  =true AND      │
             │                  │  │  'Take Profit'  │  │  triggerCondition│
             │                  │  │  → tp           │  │  exists?        │
             │                  │  │  'Stop Limit'   │  └────────┬────────┘
             │                  │  │  → sl           │           │
             │                  │  └────────┬────────┘   ┌───────┼───────┐
             │                  │           │            │ YES   │       │ NO
             │                  │           │            ▼       │       ▼
             │                  │           │  ┌─────────────────┐  ┌─────────────────┐
             │                  │           │  │  FORMAT 3:      │  │  NOT a TP/SL    │
             │                  │           │  │  Condition Parse│  │  order - SKIP   │
             │                  │           │  │  'Price above'  │  └─────────────────┘
             │                  │           │  │  → tp           │
             │                  │           │  │  'Price below'  │
             │                  │           │  │  → sl           │
             │                  │           │  └────────┬────────┘
             │                  │           │           │
             └──────────────────┴───────────┴───────────┘
                                │
                                ▼
                    ┌─────────────────────────┐
                    │  Extract trigger_price  │
                    │  from triggerPx field   │
                    └───────────┬─────────────┘
                                │
                                ▼
                    ┌─────────────────────────┐
                    │  Add to TP or SL list   │
                    │  based on tpsl_type     │
                    └─────────────────────────┘
```

### Implementation

```python
def get_tpsl_orders(self, db: Session, symbol: str):
    for order in open_orders:
        order_type = order.get('orderType', {})
        is_trigger = order.get('isTrigger', False)
        trigger_px = order.get('triggerPx')
        trigger_condition = order.get('triggerCondition', '')
        
        # Format 1: Dict with trigger info
        if isinstance(order_type, dict) and 'trigger' in order_type:
            tpsl_type = order_type['trigger'].get('tpsl')
            trigger_price = float(order_type['trigger'].get('triggerPx', 0))
        
        # Format 2: String orderType
        elif isinstance(order_type, str) and is_trigger:
            if 'take profit' in order_type.lower():
                tpsl_type = 'tp'
            elif 'stop' in order_type.lower():
                tpsl_type = 'sl'
            trigger_price = float(trigger_px) if trigger_px else 0
        
        # Format 3: triggerCondition fallback
        elif is_trigger and trigger_condition:
            if 'above' in trigger_condition.lower():
                tpsl_type = 'tp'
            elif 'below' in trigger_condition.lower():
                tpsl_type = 'sl'
            trigger_price = float(trigger_px) if trigger_px else 0
```

---

## Complete Update Flow

```
┌──────────────┐     ┌──────────────────┐     ┌─────────────────────────┐     ┌──────────────────┐
│   AI Model   │     │ trading_commands │     │ hyperliquid_trading_    │     │  Hyperliquid API │
│              │     │      .py         │     │       client.py         │     │                  │
└──────┬───────┘     └────────┬─────────┘     └───────────┬─────────────┘     └────────┬─────────┘
       │                      │                           │                            │
       │  Decision: HOLD SOL  │                           │                            │
       │  TP=130, SL=125.5    │                           │                            │
       │─────────────────────▶│                           │                            │
       │                      │                           │                            │
       │                      │  Check position exists    │                            │
       │                      │─────────────────────────▶│                            │
       │                      │                           │                            │
       │                      │  update_tpsl(SOL,130,125.5)                            │
       │                      │─────────────────────────▶│                            │
       │                      │                           │                            │
       │                      │                           │  frontend_open_orders()    │
       │                      │                           │───────────────────────────▶│
       │                      │                           │                            │
       │                      │                           │  [Order 0: SL 125.5,       │
       │                      │                           │   Order 1: TP 130]         │
       │                      │                           │◀───────────────────────────│
       │                      │                           │                            │
       │                      │                           │  Parse orders (multi-fmt)  │
       │                      │                           │  Compare: TP 130 vs 130    │
       │                      │                           │  Compare: SL 125.5 vs 125.5│
       │                      │                           │                            │
       │                      │                           │                            │
       │                      │                    ┌──────┴──────┐                     │
       │                      │                    │ PRICES MATCH │                     │
       │                      │                    │ (< 0.1% diff)│                     │
       │                      │                    └──────┬──────┘                     │
       │                      │                           │                            │
       │                      │                           │  Update cache              │
       │                      │                           │  SKIP API calls            │
       │                      │                           │                            │
       │                      │  {tp_updated: false,      │                            │
       │                      │   sl_updated: false}      │                            │
       │                      │◀─────────────────────────│                            │
       │                      │                           │                            │
       │  HOLD executed       │                           │                            │
       │  No changes needed   │                           │                            │
       │◀─────────────────────│                           │                            │
       │                      │                           │                            │


                    ─────────── ALTERNATIVE: PRICES DIFFER ───────────

       │                      │                           │                            │
       │                      │                    ┌──────┴──────┐                     │
       │                      │                    │PRICES DIFFER│                     │
       │                      │                    │ (> 0.1% diff)│                     │
       │                      │                    └──────┬──────┘                     │
       │                      │                           │                            │
       │                      │                           │  Cancel old TP order       │
       │                      │                           │───────────────────────────▶│
       │                      │                           │                            │
       │                      │                           │  Cancel old SL order       │
       │                      │                           │───────────────────────────▶│
       │                      │                           │                            │
       │                      │                           │  Place new TP order        │
       │                      │                           │───────────────────────────▶│
       │                      │                           │                            │
       │                      │                           │  Place new SL order        │
       │                      │                           │───────────────────────────▶│
       │                      │                           │                            │
       │                      │                           │  Update cache              │
       │                      │                           │                            │
       │                      │  {tp_updated: true,       │                            │
       │                      │   sl_updated: true}       │                            │
       │                      │◀─────────────────────────│                            │
       │                      │                           │                            │
       │  HOLD executed       │                           │                            │
       │  TP/SL updated       │                           │                            │
       │◀─────────────────────│                           │                            │
```

---

## In-Memory Cache

### Purpose

The cache serves as a backup mechanism when:
1. Hyperliquid API has latency returning newly created orders
2. Multiple rapid decisions occur before API reflects changes

### Structure

```python
# Cache structure: {(wallet_address, symbol): {"tp_price": float, "sl_price": float, "timestamp": int}}
_tpsl_cache: Dict[Tuple[str, str], Dict[str, Any]] = {}

def _set_cached_tpsl(wallet_address: str, symbol: str, tp_price: float, sl_price: float):
    key = (wallet_address.lower(), symbol.upper())
    _tpsl_cache[key] = {
        "tp_price": tp_price,
        "sl_price": sl_price,
        "timestamp": int(time.time() * 1000)
    }
```

### Important Notes

- Cache is **NOT the source of truth** - Hyperliquid API is
- Cache is cleared on server restart (desired behavior)
- Cache is updated after every successful TP/SL operation

---

## Configuration

### Configurable Parameters

| Parameter | Location | Default | Description |
|-----------|----------|---------|-------------|
| `PRICE_CHANGE_THRESHOLD_PERCENT` | `hyperliquid_trading_client.py` | 0.001 (0.1%) | Threshold for price comparison |
| `max_leverage` | Account settings | 3x | Maximum leverage for positions |
| `default_leverage` | Account settings | 1x | Default leverage if not specified |

### Environment Variables

No additional environment variables required. The system uses existing Hyperliquid configuration.

---

## Logging & Debugging

### Enable Debug Logs

View logs in Docker:

```bash
docker logs -f hyper-arena-app
```

### Key Log Prefixes

| Prefix | Description |
|--------|-------------|
| `[TPSL DEBUG]` | Order parsing and recognition |
| `[TPSL UPDATE]` | Price comparison and update decisions |
| `[TPSL CACHE]` | Cache operations |
| `[TPSL]` | General TP/SL operations |
| `[TPSL CHECK]` | Position existence checks |
| `[TPSL UPDATED]` | Successful updates |
| `[TPSL ERROR]` | Error conditions |

### Example Log Sequence

```
[TPSL DEBUG] SOL - Found 2 open orders
[TPSL DEBUG] Order 0: {'orderType': 'Stop Limit', 'triggerPx': '125.5', ...}
[TPSL DEBUG] Order 1: {'orderType': 'Take Profit Limit', 'triggerPx': '130.0', ...}
[TPSL DEBUG] Found string trigger order: orderType='Stop Limit', tpsl=sl, trigger_price=125.5
[TPSL DEBUG] Found string trigger order: orderType='Take Profit Limit', tpsl=tp, trigger_price=130.0
[TPSL UPDATE] SOL - API returned: TP=130.0, SL=125.5
[TPSL UPDATE] SOL - Requested: TP=130, SL=125.5
[TPSL UPDATE] SOL TP MATCHES existing: 130.0 ≈ 130 (diff=0.0000%) - SKIP
[TPSL UPDATE] SOL SL MATCHES existing: 125.5 ≈ 125.5 (diff=0.0000%) - SKIP
[TPSL UPDATE] SOL - BOTH TP and SL match existing orders - SKIPPING UPDATE ENTIRELY
[TPSL CACHE] SOL - Updated cache after operation: TP=130.0, SL=125.5
```

---

## Known Limitations

1. **Single TP/SL per Position**: System assumes one TP and one SL order per symbol. Multiple TP/SL orders are not supported.

2. **Price Rounding**: Prices are rounded to exchange precision. Small differences may occur between AI-requested and actual order prices.

3. **API Latency**: In rare cases, rapid consecutive decisions may not see the latest orders due to API propagation delay.

4. **Cache Persistence**: Cache is lost on server restart. This is intentional to ensure fresh state from exchange.

5. **Order Type Detection**: Relies on Hyperliquid API response format. Changes to API may require parser updates.

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-02-12 | Initial implementation with duplicate prevention |
| 1.1 | 2025-02-12 | Added multi-format order type recognition |
| 1.2 | 2025-02-12 | Fixed orderType string parsing for 'Take Profit Limit' and 'Stop Limit' |

---

## Related Files

- `prompts/trading_prompt_alpha_arena.md` - AI prompt with TP/SL requirements
- `backend/services/trading_commands.py` - Order execution orchestration
- `backend/services/hyperliquid_trading_client.py` - Hyperliquid API client with TP/SL methods
- `backend/services/ai_decision_service.py` - AI decision parsing
