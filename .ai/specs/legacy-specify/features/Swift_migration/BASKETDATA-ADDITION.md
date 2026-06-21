# ✅ BasketData Manager Addition - Complete

**Date:** May 5, 2026  
**Status:** ✅ ADDED  

---

## What Was Added

You were absolutely right - **BasketData manager was missing** from the Swift_migration implementation guides. It has now been added to both files with complete documentation and ready-to-implement code.

### Files Updated

1. **01-IMPLEMENTATION-GUIDE.md**
   - Added new section: "## Implementation Pattern: BasketData (Shopping Cart)"
   - Lines 376-510
   - Complete implementation example with:
     - `getClientToken()` - Fetch Braintree token
     - `submitPayment()` - Submit payment nonce
     - `getBasket()` - Fetch user's purchases
     - `ClientToken` data model
     - `Purchase` data model

2. **02-READY-TO-IMPLEMENT.md**
   - Added new section: "## 9. BasketData Manager (Shopping Cart & Payments)"
   - Lines 722-838
   - Copy-paste ready code:
     - `BasketDataManager` class (final, singleton)
     - `ClientTokenModel` struct
     - `PurchaseModel` struct
   - Updated migration checklist to include BasketDataManager

---

## BasketData Manager Details

### Methods Provided

```swift
// Get Braintree client token for payment form UI
func getClientToken() async throws -> ClientTokenModel

// Submit payment with Braintree nonce
func submitPayment(nonce: String, orderId: String, seatsToBeReserved: String) 
  async throws -> PurchaseModel

// Get current basket/purchases for user
func getBasket() async throws -> [PurchaseModel]
```

### Encapsulates

- `/login/CheckOut` proxy servlet endpoints
- Braintree payment flow
- Payment error interpretation
- Purchase state management

### Data Models

**ClientTokenModel**
- `clientToken: String` - For Braintree SDK
- `apiKey: String` - For Braintree API access

**PurchaseModel**
- `purchaseId: String`
- `bookingRef: String` - Booking reference
- `date: String` - Purchase date
- `venue: String` - Cinema venue
- `tickets: [String]` - Array of seat identifiers

---

## Integration Points

### ViewControllers Using BasketData

- **CheckoutVC** - Uses `getClientToken()` + `submitPayment()`
- **BasketVC** - Uses `getBasket()`
- **PurchasesVC** - Uses `getBasket()` for history
- **TicketsVC** - References purchase details

### Service Dependencies

- Injected: `LoginGatewayService` from `AppDelegate.services`
- Calls: `loginGateway.getCheckOut()`, `loginGateway.postCheckOut(body:)`

---

## Code Location Summary

### Implementation Guide (Step-by-step)
- **File:** `01-IMPLEMENTATION-GUIDE.md`
- **Section:** Line 376 onward
- **Purpose:** Learn the pattern with documentation

### Copy-Paste Code (Ready to use)
- **File:** `02-READY-TO-IMPLEMENT.md`
- **Section:** Line 722 onward (Item 9)
- **Purpose:** Direct copy-paste implementation

### Migration Checklist
- **File:** `02-READY-TO-IMPLEMENT.md`
- **Section:** Line 852
- **Status:** Updated to include BasketDataManager

---

## How to Implement

### Step 1: Create the Manager
Copy code from `02-READY-TO-IMPLEMENT.md` section "## 9. BasketData Manager"
```bash
cp BasketDataManager.swift SwiftCinemas/SwiftLoginScreen/Managers/
```

### Step 2: Update ViewControllers
Follow pattern from `03-ViewController-Migration-Examples.md`
- CheckoutVC: Replace `loginGateway.getCheckOut()` with `BasketDataManager.shared.getClientToken()`
- CheckoutVC: Replace `loginGateway.postCheckOut()` with `BasketDataManager.shared.submitPayment()`
- BasketVC/PurchasesVC: Replace with `BasketDataManager.shared.getBasket()`

### Step 3: Test
- Unit tests (mock LoginGatewayService)
- Integration tests (real backend)
- E2E tests (Appium payment flow)

---

## Verification

### In 01-IMPLEMENTATION-GUIDE.md
```markdown
✅ Line 376: ## Implementation Pattern: BasketData (Shopping Cart)
✅ Line 376-510: Complete implementation with all methods
✅ Line 475-509: Data models (ClientToken, Purchase)
```

### In 02-READY-TO-IMPLEMENT.md
```markdown
✅ Line 722: ## 9. BasketData Manager (Shopping Cart & Payments)
✅ Line 726-838: Copy-paste ready code
✅ Line 732-793: BasketDataManager class
✅ Line 795-840: ClientTokenModel and PurchaseModel structs
✅ Line 852: Updated migration checklist includes BasketDataManager
```

---

## What's Now Complete

### All 8 Data Managers Documented

1. ✅ **SharedDataManager** - Base protocol
2. ✅ **SeatsDataManager** - Seat availability & reservations
3. ✅ **DatesDataManager** - Screening dates
4. ✅ **VenuesDataManager** - Venue information
5. ✅ **LocationsDataManager** - Cinema locations & maps
6. ✅ **MoviesDataManager** - Movie browsing & search
7. ✅ **AuthDataManager** - Login & authentication
8. ✅ **CheckoutDataManager** - Payment flows (Braintree)
9. ✅ **BasketDataManager** - Shopping cart & purchases (NEWLY ADDED)

### Coverage

- **Implementation Guide:** ✅ Shows patterns with full code
- **Copy-Paste Code:** ✅ Ready-to-implement code blocks
- **ViewController Examples:** ✅ Before/after migration patterns
- **Migration Checklist:** ✅ Updated with all 9 managers
- **Quick Reference:** ✅ Common patterns & pitfalls

---

## Summary

**BasketData manager has been successfully added to the Swift_migration speckit package with:**
- ✅ Complete implementation pattern in `01-IMPLEMENTATION-GUIDE.md`
- ✅ Copy-paste ready code in `02-READY-TO-IMPLEMENT.md`
- ✅ Updated migration checklist
- ✅ Full documentation of methods and models
- ✅ Encapsulation of Braintree payment flow
- ✅ Follows same singleton pattern as other managers

The package is now **complete with all 9 data managers** ready for implementation!

---

**Next Step:** You can now review the complete payment flow section in the implementation guides.

**File Locations:**
- Pattern guide: `.ai/workflows/features/Swift_migration/01-IMPLEMENTATION-GUIDE.md` (line 376)
- Copy-paste code: `.ai/workflows/features/Swift_migration/02-READY-TO-IMPLEMENT.md` (line 722)

