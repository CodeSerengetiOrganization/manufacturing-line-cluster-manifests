# manufacturing-line-cluster-manifests-
This is a GitOps-style Deployment/Infra Repo for manufacturing line related applications and infrastructures.

## Release Management with `release.yaml`

The `release.yaml` file in each environment directory (`envs/dev/`, `envs/sit/`, `envs/prod/`) serves as the single source of truth for component versions in coordinated deployments.

### Structure

Each `release.yaml` file contains:

- **Bundle Version**: A calendar-versioned identifier (format: `YYYY.MM.DD.NN`) that tracks coordinated deployments across multiple services
- **Metadata**: Information about who updated the release, the reason, and deployment status
- **Component Versions**: Specific version tags/SHAs for each deployable component

### Component Keys

Component keys in `release.yaml` **must match** the Kubernetes deployment names defined in the `base/` directory:

- `mms-backend` → matches `base/backend/deployment.yaml` (name: `mms-backend`)
- `mms-frontend` → matches `base/frontend/frontend-deployment.yaml` (name: `mms-frontend`)
- `mysql` → matches `base/db/mysql-deployment.yaml` (name: `mysql`)
- `kafka` → Infrastructure component (if applicable)

### Usage

1. **Before a Coordinated Deployment**:
   - Update the `version` field using calendar versioning (e.g., `2025.12.26.01`)
   - Update component versions with the specific tags/SHAs to deploy
   - Update `metadata.updated_by`, `metadata.reason`, and `metadata.status`

2. **Example Workflow**:
   ```yaml
   version: 2025.12.26.02  # Increment for new coordinated release
   
   metadata:
     updated_by: "Your Name"
     reason: "Deploying bug fixes for backend and frontend"
     status: "DEV_PASSED"
   
   components:
     mms-backend: "v1.0.1"      # Updated version
     mms-frontend: "v1.1.1"     # Updated version
     mysql: "mysql-8.0.33"      # Unchanged
     kafka: "3.5.1"             # Unchanged
   ```

3. **Deployment Scripts**:
   - Deployment scripts should read from `release.yaml` to determine which versions to deploy
   - Component keys are used to map to the corresponding Kubernetes deployments in `base/`

### Best Practices

- Always increment the bundle version when making coordinated changes across multiple services
- Keep component versions in sync with actual container image tags in your registry
- Update metadata to track deployment history and status
- Use environment-specific `release.yaml` files to manage different versions per environment

### Note

Now this version of `release.yaml` only for manually check, not yet integrated into CI/CD pipeline for automated vresion check.