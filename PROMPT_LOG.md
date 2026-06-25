## ENTRY 1: Candidate 2 Main Code Analysis (June 23, 2026, ChatGPT)

Context: 
Needed a full scale evaluation of the codebase of Candidate 2, team_3_f25_project. Needed to 
focus on overall strengths, weaknesses, architechure, and feasibility for ReadRight2.0.

Prompt Excerpt: 
Analyze this Flutter codebase and identify potential strengths, weaknesses, architecture, user expereince,
educational effectiveness, and code quality. Provide examples from the codebase to support the claims.

AI Summary: 
The AI response included an exerpt for every category requested, inlcuding details about the codebase
to ensure no information was fabricated. 

Human Evaluation: 
The analysis was sound, with code examples from the codebase to supoort all points and claims about 
strengths, weaknesses, and otherwise details.

Final Decision: 
This analysis was extremely helpful for deciding which applciation to use as a basis for ReadRight2.0


## Entry 2 Claude (June 21, 2026)

Context

We were analyzing the architecture of the WitherTigher/Capstone-Project-RW codebase to evaluate whether it was a sound foundation to build a semester project on.

Prompt Excerpt

"Analyze this Flutter codebase across six dimensions: strengths, weaknesses, architecture, UX for young users, educational effectiveness, and code quality. Be specific and cite actual file names and code patterns"

AI Summary

Claude identified the Azure pronunciation pipeline in practice.dart as the strongest asset, flagged feedback.dart as entirely hardcoded placeholder content disconnected from real data, noted the 871-line practice screen as the biggest architectural risk, and flagged the Supabase credential hardcoded in config.dart as an immediate security issue.

Human Evaluation

The architectural assessment was accurate and matched what we found when we opened the files ourselves. The security findings were confirmed in config.dart and pubspec.yaml. The claim about feedback.dart was verified by opening the file and finding the hardcoded word "cat", a score of 0.88, and a "Next word feature coming soon" snackbar.

Final Decision

Accepted with modification. We used Claude's analysis as a starting framework but rewrote the evaluation in our own words and added observations Claude missed, including the flutter_dotenv misconfiguration and the 2000+ linter warnings visible on import.

Testing and Verification

We opened practice.dart and confirmed the feedback field is hardcoded to "Good job" regardless of score. We opened feedback.dart and confirmed the hardcoded word, score, and phoneme chips. We opened pubspec.yaml and confirmed mockito under dependencies and three unused Firebase packages listed despite Firebase never being used.

## Entry 3 ChatGPT (June 22, 2026) 

Context
We were evaluating the educational effectiveness of the WitherTigher codebase to determine whether it actually teaches children to read or just drills them on words.

Prompt Excerpt

"Given that this app uses Azure Pronunciation Assessment and Dolch word lists, does it meet the criteria for an educationally effective tool for early readers? What is missing from a learning standpoint?"

AI Summary

ChatGPT noted that the app functions as a drill tool rather than a teaching tool. It presents words and records pass or fail but has no spaced repetition, no session structure, no phoneme level feedback shown to students, and no adaptive difficulty. It suggested adding spaced repetition and session stopping points as high priority improvements.

Human Evaluation

The assessment was accurate but somewhat generic. ChatGPT described what a good literacy app should have without specifically tying it to what was present or absent in this codebase. We had to verify each claim against the actual code to confirm which gaps were real.

Final Decision

Modified. We accepted the general framework of what was missing but replaced the generic recommendations with specific observations tied to actual files, such as the fact that Azure returns per-phoneme data that never reaches the student, and that the feedback field in every attempt row is hardcoded to "Good job" regardless of score.

Testing and Verification

We confirmed no spaced repetition logic exists anywhere in the codebase by searching for relevant terms across all service files. We confirmed the always "Good job" feedback string in practice.dart. We confirmed Azure returns phoneme level data by reviewing the AssessmentResult model and noting it is never passed to feedback.dart.

