# Release checklist

## One-time setup

- [ ] Create the GitHub repository and add it as `origin`.
- [ ] Replace `OWNER/REPO` placeholders in `CHANGELOG.md` and `README.md`.
- [ ] Decide whether the repository is public. npm provenance is unavailable for private repositories.
- [ ] Claim the `vc-funding` package name on npm.
- [ ] Configure npm trusted publishing for `.github/workflows/publish-npm.yml`.
- [ ] Create a Homebrew tap and commit the generated `Casks/vc-funding.rb` there.
- [ ] For a warning-free macOS download, configure Developer ID signing and notarization.

## Every release

1. Update the version in `package.json` and `support/Info.plist`.
2. Update `CHANGELOG.md` and `RELEASE_NOTES.md`.
3. Run the release checks:

   ```sh
   ./scripts/check-release.sh 0.1.0
   ```

4. Commit the release preparation.
5. Create and push the matching tag:

   ```sh
   git tag -s v0.1.0 -m "vc-funding 0.1.0"
   git push origin master v0.1.0
   ```

6. The release workflow creates a **draft** GitHub release with the `.app` archive, SHA-256 file, and npm tarball.
7. Verify the attached artifacts before publishing the GitHub release.
8. Publishing the GitHub release triggers the npm trusted-publishing workflow.
9. Generate the final Homebrew Cask with the immutable GitHub release URL and push it to the tap.

Do not create the tag until the remote URLs, npm publisher, and signing policy are settled.
