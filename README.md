# rubocop-feature-revisions-consistency

See details at [this blog post](https://viralpraxis.github.io/2023/10/12/custom-rubocop-rule-to-ensure-feature-consistency.html).

Note that this cop is running iff `RUBOCOP_RUN_CACHELESS_COPS` environment variable is provided:

```bash
RUBOCOP_RUN_CACHELESS_COPS=true bundle exec rubocop --only Lint/FeatureRevisionsConsistency
```
