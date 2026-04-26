# AWS Forensic Auditing Lab (Athena & CloudTrail)

This lab demonstrates a critical security and compliance pattern for the **AWS SysOps Administrator Associate**: using **Amazon Athena** to perform SQL-based forensics on **AWS CloudTrail** logs.

## Architecture Overview

The system implements a high-fidelity audit and investigation pipeline:

1.  **Event Capture:** AWS CloudTrail records all API activity (management events) within the account.
2.  **Secure Storage:** Audit logs are delivered to a dedicated, policy-protected S3 bucket (\`sysops-audit-logs-bucket\`).
3.  **Schema Projection:** Amazon Athena defines a database (\`cloudtrail_audit_db\`) and table structure that projects a schema onto the raw JSON logs stored in S3.
4.  **Forensic Investigation:** Analysts can use standard SQL queries to investigate security incidents, track resource changes, and audit user activity with high precision.
5.  **Query Lifecycle:** A separate S3 bucket manages the lifecycle of Athena query results for governance and performance.

## Key Components

-   **AWS CloudTrail:** The definitive source of truth for API activity.
-   **Amazon Athena:** The serverless interactive query service.
-   **S3 Bucket Policies:** Enforce the secure delivery of audit data.
-   **Athena Workgroups:** Control and monitor query execution and costs.

## Prerequisites

-   [Terraform](https://www.terraform.io/downloads.html)
-   [LocalStack Pro](https://localstack.cloud/)
-   [AWS CLI / awslocal](https://github.com/localstack/awscli-local)

## Deployment

1.  **Initialize and Apply:**
    ```bash
    terraform init
    terraform apply -auto-approve
    ```

## Verification & Testing

To test the forensic auditing pipeline:

1.  **Verify Trail Status:**
    ```bash
    awslocal cloudtrail describe-trails
    aws cloudtrail describe-trails
    ```

2.  **Confirm Log Delivery:**
    Check that CloudTrail has started writing logs to S3:
    ```bash
    awslocal s3 ls s3://sysops-audit-logs-bucket --recursive
    aws s3 ls s3://sysops-audit-logs-bucket --recursive
    ```

3.  **Execute a Forensic Query (Conceptual):**
    In Athena, you would create a table and then run a query like:
    ```sql
    SELECT eventname, useridentity.arn, eventtime
    FROM cloudtrail_logs
    WHERE eventname = 'DeleteBucket'
    ORDER BY eventtime DESC;
    ```

4.  **Check Athena Results:**
    Verify that query result metadata is being stored:
    ```bash
    awslocal s3 ls s3://sysops-athena-results-bucket --recursive
    aws s3 ls s3://sysops-athena-results-bucket --recursive
    ```

## Cleanup

To tear down the infrastructure:
```bash
terraform destroy -auto-approve
```

---

💡 **Pro Tip: Using `aws` instead of `awslocal`**

If you prefer using the standard `aws` CLI without the `awslocal` wrapper or repeating the `--endpoint-url` flag, you can configure a dedicated profile in your AWS config files.

### 1. Configure your Profile
Add the following to your `~/.aws/config` file:
```ini
[profile localstack]
region = us-east-1
output = json
# This line redirects all commands for this profile to LocalStack
endpoint_url = http://localhost:4566
```

Add matching dummy credentials to your `~/.aws/credentials` file:
```ini
[localstack]
aws_access_key_id = test
aws_secret_access_key = test
```

### 2. Use it in your Terminal
You can now run commands in two ways:

**Option A: Pass the profile flag**
```bash
aws iam create-user --user-name DevUser --profile localstack
```

**Option B: Set an environment variable (Recommended)**
Set your profile once in your session, and all subsequent `aws` commands will automatically target LocalStack:
```bash
export AWS_PROFILE=localstack
aws iam create-user --user-name DevUser
```

### Why this works
- **Precedence**: The AWS CLI (v2) supports a global `endpoint_url` setting within a profile. When this is set, the CLI automatically redirects all API calls for that profile to your local container instead of the real AWS cloud.
- **Convenience**: This allows you to use the standard documentation commands exactly as written, which is helpful if you are copy-pasting examples from AWS labs or tutorials.
