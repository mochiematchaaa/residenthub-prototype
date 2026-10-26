// Live connection between this app and the City Residences website.
//
// 1. Create a free project at https://supabase.com
// 2. Run database/schema.sql in the SQL Editor (step by step: database/SETUP-STEP-BY-STEP.md)
// 3. Paste the Project URL and the "anon public" key below
//    (Project Settings > API). The anon key is meant to be public - it is safe to commit.
//    NEVER paste the "service_role" key or the database password here.
//
// The values below are the REAL project. To test with your own database, replace them or use --dart-define (below).
//
// Instead of editing this file you can also build with
//   --dart-define=SUPABASE_URL=...  --dart-define=SUPABASE_ANON_KEY=...
// (the GitHub Action reads the repository variables SUPABASE_URL and SUPABASE_ANON_KEY).

const String _urlHere = 'https://iexsitqmmhokmffmmaed.supabase.co';
const String _keyHere = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlleHNpdHFtbWhva21mZm1tYWVkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTE4OTgzNDEsImV4cCI6MjEwNzQ3NDM0MX0.g1-1z0XOp0RpFot_OP06_1_6nPPvueyqArVtP3qYcwc';

const String _urlDefine = String.fromEnvironment('SUPABASE_URL');
const String _keyDefine = String.fromEnvironment('SUPABASE_ANON_KEY');

String get supabaseUrl => _urlDefine.isNotEmpty ? _urlDefine : _urlHere;
String get supabaseAnonKey => _keyDefine.isNotEmpty ? _keyDefine : _keyHere;
bool get cloudConfigured => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
