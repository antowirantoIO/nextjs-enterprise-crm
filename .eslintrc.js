const path = require('path');

/** @type {import('eslint').Linter.Config} */
module.exports = {
    extends: [
        'next/core-web-vitals',
        '@typescript-eslint/recommended',
        'prettier',
        'plugin:tailwindcss/recommended',
    ],
    parser: '@typescript-eslint/parser',
    parserOptions: {
        project: path.join(__dirname, 'tsconfig.json'),
    },
    plugins: ['@typescript-eslint', 'import', 'jsx-a11y'],
    rules: {
        // TypeScript
        '@typescript-eslint/no-unused-vars': [
            'error',
            {
                argsIgnorePattern: '^_',
                varsIgnorePattern: '^_',
                caughtErrorsIgnorePattern: '^_',
            },
        ],
        '@typescript-eslint/consistent-type-imports': [
            'warn',
            {
                prefer: 'type-imports',
                fixStyle: 'inline-type-imports',
            },
        ],
        '@typescript-eslint/no-misused-promises': [
            2,
            {
                checksVoidReturn: {
                    attributes: false,
                },
            },
        ],
        '@typescript-eslint/no-explicit-any': 'warn',
        '@typescript-eslint/prefer-nullish-coalescing': 'error',
        '@typescript-eslint/prefer-optional-chain': 'error',

        // Import
        'import/order': [
            'error',
            {
                groups: [
                    'builtin',
                    'external',
                    'internal',
                    'parent',
                    'sibling',
                    'index',
                    'object',
                ],
                'newlines-between': 'always',
                alphabetize: {
                    order: 'asc',
                    caseInsensitive: true,
                },
                pathGroups: [
                    {
                        pattern: 'react',
                        group: 'external',
                        position: 'before',
                    },
                    {
                        pattern: 'next/**',
                        group: 'external',
                        position: 'before',
                    },
                    {
                        pattern: '@/**',
                        group: 'internal',
                    },
                ],
                pathGroupsExcludedImportTypes: ['react'],
            },
        ],

        // React
        'react/prop-types': 'off',
        'react/react-in-jsx-scope': 'off',
        'react-hooks/rules-of-hooks': 'error',
        'react-hooks/exhaustive-deps': 'warn',

        // General
        'prefer-const': 'error',
        'no-var': 'error',
        'no-console': process.env.NODE_ENV === 'production' ? 'error' : 'warn',
        'no-debugger': process.env.NODE_ENV === 'production' ? 'error' : 'warn',

        // Tailwind
        'tailwindcss/no-custom-classname': 'off',
        'tailwindcss/classnames-order': 'warn',

        // Accessibility
        'jsx-a11y/alt-text': [
            'warn',
            {
                elements: ['img'],
                img: ['Image'],
            },
        ],
        'jsx-a11y/aria-props': 'warn',
        'jsx-a11y/aria-proptypes': 'warn',
        'jsx-a11y/aria-unsupported-elements': 'warn',
        'jsx-a11y/role-has-required-aria-props': 'warn',
        'jsx-a11y/role-supports-aria-props': 'warn',
    },
    settings: {
        tailwindcss: {
            callees: ['cn', 'cva'],
            config: path.join(__dirname, 'tailwind.config.ts'),
        },
        next: {
            rootDir: ['./'],
        },
    },
    overrides: [
        {
            files: ['*.ts', '*.tsx'],
            parser: '@typescript-eslint/parser',
        },
    ],
    ignorePatterns: [
        '*.js',
        '*.jsx',
        'node_modules/',
        '.next/',
        'out/',
        'dist/',
        'build/',
        'coverage/',
        '.storybook/',
        'storybook-static/',
        '*.config.js',
        '*.config.ts',
    ],
};