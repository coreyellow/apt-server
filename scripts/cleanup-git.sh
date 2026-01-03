git checkout --orphan temp_branch && git add . && git commit -m "Flattened repository" && git branch -D main && git branch -m main && git push -f origin main
