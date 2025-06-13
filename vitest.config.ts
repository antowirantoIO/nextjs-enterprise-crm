import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';
import path from 'path';

export default defineConfig({
    plugins: [react()],
    test: {
        globals: true,
        environment: 'jsdom',
        setupFiles: ['./tests/setup/test-setup.ts'],
        include: [
            'src/**/*.{test,spec}.{js,mjs,cjs,ts,mts,cts,jsx,tsx}',
            'tests/unit/**/*.{test,spec}.{js,mjs,cjs,ts,mts,cts,jsx,tsx}',
        ],
        exclude: [
            'node_modules',
            'dist',
            '.next',
            'coverage',
            'tests/e2e/**',
            'tests/integration/**',
        ],
        coverage: {
            provider: 'v8',
            reporter: ['text', 'json', 'html'],
            exclude: [
                'node_modules/',
                'tests/',
                '**/*.d.ts',
                '**/*.config.*',
                '**/coverage/**',
                '**/dist/**',
                '**/.next/**',
                '**/build/**',
                'src/app/**/layout.tsx',
                'src/app/**/loading.tsx',
                'src/app/**/error.tsx',
                'src/app/**/not-found.tsx',
                'src/app/**/page.tsx',
                'src/middleware.ts',
                'src/instrumentation.ts',
            ],
            thresholds: {
                global: {
                    branches: 80,
                    functions: 80,
                    lines: 80,
                    statements: 80,
                },
            },
        },
        reporters: ['verbose'],
        outputFile: {
            json: './coverage/test-results.json',
            junit: './coverage/junit.xml',
        },
    },
    resolve: {
        alias: {
            '@': path.resolve(__dirname, './src'),
            '@/components': path.resolve(__dirname, './src/components'),
            '@/lib': path.resolve(__dirname, './src/lib'),
            '@/app': path.resolve(__dirname, './src/app'),
            '@/styles': path.resolve(__dirname, './src/styles'),
            '@/types': path.resolve(__dirname, './src/lib/types'),
            '@/hooks': path.resolve(__dirname, './src/lib/hooks'),
            '@/stores': path.resolve(__dirname, './src/lib/stores'),
            '@/utils': path.resolve(__dirname, './src/lib/utils'),
            '@/config': path.resolve(__dirname, './src/lib/config'),
            '@/services': path.resolve(__dirname, './src/lib/services'),
        },
    },
});