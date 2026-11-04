# APEX application export

`f54570.sql` is the export of the Hypertension Monitoring application (application 54570, 10 pages), exported from Oracle APEX 26.2.

Developer account names in the export have been replaced with `DEVELOPER`. They are audit labels only and do not affect how the application works.

## How to import

1. Run the database scripts in [`../sql`](../sql) first, in order. The application needs the tables and the `SUBMIT_READING` procedure.
2. In App Builder, click **Import**, choose `f54570.sql`, and follow the wizard.
3. If application ID 54570 is already used in your workspace, choose **Auto Assign New Application ID**.
4. Sign in with an APEX account from your own workspace.
