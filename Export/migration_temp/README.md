# Migration Temp - Backup Directory

**Status:** Preserved for safety  
**Date:** October 5, 2025  
**Purpose:** Backup of original test files during migration

---

## Overview

This directory contains **all original test files** that were present before the test suite migration project. These files are preserved as a safety backup and historical reference.

**Important:** These files are **NOT** used by the new test suite in `new_tests/`.

---

## Contents

- All original test files from `Export/` and `Export/tests/`
- Original fixture files from `tests/fixtures/`
- All documentation and supporting files

---

## Migration Status

✅ **Migration Complete** - All valuable tests have been:
- Migrated to `new_tests/` (essential & optional tests)
- Archived in `new_tests/archive/` (reference tests)
- Or deprecated (not needed)

---

## Retention Policy

**Recommendation:** Keep this directory for **30-60 days** after migration completion.

**Reason:** Provides rollback capability if any issues are discovered with the new test suite.

**After validation period:**
- Can be safely deleted if new test suite is working well
- Or compress to `.tar.gz` for long-term archival storage

---

## Rollback Procedure

If needed to rollback to original tests:

```bash
cd /path/to/gdsii-toolbox-146/Export
# Backup new tests (just in case)
mv new_tests new_tests_backup
# Restore from migration_temp
cp -r migration_temp/* .
```

**Note:** This should only be needed if catastrophic issues are found with new test suite.

---

**Created:** October 5, 2025  
**Next Review:** November 5, 2025 (30 days)  
**Action:** Delete or archive after validation period
