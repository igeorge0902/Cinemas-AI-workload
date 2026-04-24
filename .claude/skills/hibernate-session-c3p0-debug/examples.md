# Examples: Hibernate Session C3P0 Debug

## Example 1
### Input
Checkout intermittently fails during load with transaction/session errors around seat booking.

### Output
- Maps failing endpoint to `DAO.bookTickets()` flow.
- Verifies transaction open/commit/rollback paths are symmetric.
- Checks `hibernate.cfg.xml` c3p0 pool/timeouts against thread load.
- Returns minimal fix target and validation run steps.

## Example 2
### Input
Random `Session is closed` appears in movie list flow after refactor.

### Output
- Traces endpoint to DAO read path and session creation source in `HibernateUtil`.
- Identifies early session close or leaked exception path.
- Proposes focused code/config patch.
- Verifies via repeat API calls and error-log absence.

