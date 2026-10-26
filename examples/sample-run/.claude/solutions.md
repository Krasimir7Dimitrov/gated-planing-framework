# Solutions \- Audit Log Feature

💡

## Solution: AuditLog Schema Design

### Draft (Claude)

**Constraint:** Each column must store exactly one piece of information (C9). All fields for the four new log entry types must be definable using pre-existing AuditLog columns \- no new columns may be introduced unless no existing column can carry the needed primitive value. **Extensibility assessment:** NO \- schema is a one-time structural decision; the AuditLog entity is a complete, pre-existing design that does not require extension for this task. **Naive approach:** Use the existing AuditLog entity without modification. All four confirmed decisions write single primitive values into the pre-existing `entity_type`, `operation_type`, `old_value`, `new_value`, and `subject_id` columns. Verified at `src/Entity/AuditLog.php:14-191`. **Evidence checklist:**

- Every aspect of the naive approach has a specific file:line citation: YES \- `src/Entity/AuditLog.php:14` (entity), `:23-86` (all 10 column definitions verified in decision-inventory.md)  
- The citations cover ALL fields and behaviors \- not just part of the constraint: YES \- all 10 columns verified: id, subject\_id, entity\_type, operation\_type, old\_value, new\_value, user\_id, user\_email, tenant\_id, created\_at; schema confirmed against `migrations/Version20250527120000.php`  
- No aspect relies on general framework knowledge without project-specific proof: YES \- entity file was read directly; migration file confirms schema matches entity **Self-select:** YES (all three YES) **Options:**  
- A: Use existing AuditLog entity \- all 10 columns confirmed at `src/Entity/AuditLog.php:14-191`; each of the four confirmed decisions maps entirely onto existing columns with no remainder; C9 verified for every column in decision-inventory.md **Reference field coverage:** N/A \- AuditLog is the Back Office's own pre-existing entity. The meeting's reference (`## References to Existing Functionality`) points to the reference-app *logging pattern* (how to log), not to a reference-app entity whose fields must be mirrored into AuditLog. No field-by-field INCLUDE/EXCLUDE decision was required. The reference-app reference was evaluated in scope.md and the gap-analyzer confirmed the same raw-primitive/FE-assembles architecture already applies to AuditLog. **Project files relevant to this constraint:** `src/Entity/AuditLog.php`, `migrations/Version20250527120000.php`