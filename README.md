# git-jira-hook

Git hook to update JIRA server with commit info. This is a simple set of bash scripts which can be used to update a jira server with git commit information.

This work as following:
- When a user writes a commit message in git it used the name of a JIRA issue in the format PROJECT_CODE-PROJECT_NUMBER (ie. JVIN-7893). Multiple issues separated by comma are supported. Each will be updated.
- On push the server post-receive hook updates the corresponding JIRA issue via REST API.
- The issue custom field will be updated to contain (note that this contains JIRA wiki code)
```
*short_hash*/branch_name - commiter_name on short_date
commit_message
- list of files modified
----
```

## Prerequisites

- the JIRA project must have a custom_field configured of type multi-line text configured with a wiki-style renderer. JIRA config can be quite complicated so refer to [JIRA doc](https://confluence.atlassian.com/adminjiraserver073/configuring-renderers-861253418.html) for that.
- a user with access to REST API and which can update issues on this project is required

## Installation

- install this on a folder on the git server
- create a link inside project.git/hooks/post-receive -> post-receive-jira.sh

## Cleanup

Note that this will create a list of updated tracks inside *jira_refs.txt*. If you want to clean the custom field of all these tracks (ie for testing) run: `clean-gitlog.sh`

## Historical

You can run this script to update the git from old history, or for testing with a command similar to:
```
git log --after={2019-09-23} --pretty=%h | while read rev; do /home/len/free/jiraGitLog/post-receive-jira.sh manual $rev; done
```
this will update the issues referenced in all commits since 23 sept 2019 for instance or
```
./post-receive-jira.sh manual 920fae70ae
```
to update the jira issue referenced in commit 920fae70ae

## Example 

![screenshot][git-jira.hook.png]

