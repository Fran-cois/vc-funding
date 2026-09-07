# Release checklist

## One-time setup

- [x] Create the public GitHub repository and add it as `origin`.
- [x] Configure repository URLs in the app, changelog, and README.
- [x] Create a Homebrew tap and commit the generated `Casks/vc-funding.rb` there. (tap: `Fran-cois/homebrew-tap`)
- [ ] For a warning-free macOS download, configure Developer ID signing and notarization.

## Every release

1. Update the version in `support/Info.plist`.
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

6. The release workflow creates a **draft** GitHub release with the `.app` archive and SHA-256 file.
7. Verify the attached artifacts before publishing the GitHub release.
8. Generate the final Homebrew Cask with the immutable GitHub release URL and push it to the tap.

Do not create the tag until the remote URLs and signing policy are settled.
