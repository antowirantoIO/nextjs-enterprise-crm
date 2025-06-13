module.exports = {
    branches: [
        'main',
        'next',
        { name: 'beta', prerelease: true },
        { name: 'alpha', prerelease: true },
    ],
    plugins: [
        '@semantic-release/commit-analyzer',
        '@semantic-release/release-notes-generator',
        '@semantic-release/changelog',
        '@semantic-release/npm',
        [
            '@semantic-release/git',
            {
                assets: ['CHANGELOG.md', 'package.json', 'package-lock.json'],
                message: 'chore(release): ${nextRelease.version} [skip ci]\n\n${nextRelease.notes}',
            },
        ],
        '@semantic-release/github',
    ],
    preset: 'conventionalcommits',
    releaseRules: [
        { type: 'feat', release: 'minor' },
        { type: 'fix', release: 'patch' },
        { type: 'perf', release: 'patch' },
        { type: 'revert', release: 'patch' },
        { type: 'docs', scope: 'README', release: 'patch' },
        { type: 'refactor', release: 'patch' },
        { type: 'style', release: false },
        { type: 'chore', release: false },
        { type: 'test', release: false },
        { scope: 'no-release', release: false },
    ],
    parserOpts: {
        noteKeywords: ['BREAKING CHANGE', 'BREAKING CHANGES'],
    },
    writerOpts: {
        commitsSort: ['subject', 'scope'],
    },
};