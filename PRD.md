### PRD for GirlsGoGames

## Pillar 1: Speech & Pronunciation
The existing bugs will be fixed, including the feedback screen (mentioned more in the UX critique below). There will be a more defined strcuture between words with visual cues and stopping points, rather than the current continuous cycle. Constant learning and not pausing would easily tire a child's mind.

We will extract all audio capture and assessment logic out of the practice screen into a dedicated pronunciation service behind a single,swapable interface: Azure PronunciationAssessor. Speechace is planned as a secondary provider if Azure was to fail implenmantion. It performs true articulation scoring rather than transcription matching, making minimal-pair practice (read/lead) meaningful. If needed, Whisper/Vosk will will used as a secondary/offline provider, but not as the primary assessment. 

The resulting score will be represented as visual feedback for the child (ie. stars, emojis) and an encouraging message keyed to score bands rather than a number alone. Recordings are capped at 3 seconds.

## Pillar 2: AI Story Builder
The Story Builder generates short, personalized stories built around a student's target Dolch words, so children practice sight words in connected reading rather than in isolation. This is the pedagogical bridge between the app's existing word-level practice and real reading: a child who can pronounce "said" in the speech pillar and recognize it in a game now encounters it repeatedly inside a story about a topic they care about.

Dolch words are high-frequency words that must be recognized automatically for fluent reading; research-backed practice puts them in context, not just flashcards. Personalizing by interest increases engagement and re-reading, and constraining the vocabulary to the target list plus level-appropriate filler means every story is dense with the exact words the student is working on. The teacher's level selection keeps text decodable for that specific child.

Story generation is teacher-only. The teacher selects a reading level and optionally any target Dolch words to appear or intersets. Students read the resulting stories but never call the model directly. This keeps an adult in the loop for content review, controls API volume, and is our first content-safety layer. The created story will appear as an option for the student to read, but students cannot call the story generator directly.This keeps an adult in the loop, controls volume, and supports content safety. Topics will be avaible from a provided list to constrain topics to age-appropriate material, filter the interest input, and keep generated text at the target level using a controlled vocabulary centered on the chosen Dolch words.

Story generation uses gpt mini-tier via the course OpenAI allocation, satisfying the mini-tier cost requirement. The generation prompt is a core design artifact: it specifies reading level, a required-word list drawn from the chosen Dolch set, a controlled-vocabulary instruction, and story length. Output is requested in a structured format (title + story text). The API key will be stored locally as an environment variable in an .env, marked in .gitignore, and not committed to the repository. There will be a mounted button and rate limiter in place, to prevent multiple requests.

## Pillar 3: Dolch Sight-Words
There will be 2 games featured:

**Fill in the Blank**
The student is shown a sentence from the Dolch database with one sight word removed and selects the correct word from 3–4 options. This tests recognition in context rather than isolation, which is a more demanding skill and closer to real reading. Distractors will be drawn from the same Dolch level so the choice is meaningful rather than guessable. This game also reuses the example sentences already in the Dolch database, so no new content pipeline is required for a first version.

**Tap the Word**
The app speaks a Dolch word aloud and the student taps the matching printed word from a set of on-screen options. This targets the audio-to-print connection ,a distinct skill from reading aloud, and complements the speech pillar by reversing its direction (hear-then-identify instead of see-then-say). We will utlize the 

## DMMT-style UX critique of the inherited app
A child would hesistate on the path and where to click. The first login in page would be done but instinct of previous apps, but not guided by this sepcific app. What to click and where to go are not obvious. 

2 identical "start practice" buttons is also a major issue plus there is also a practice tab that has the same purpose. Every extra decision increases hesitation.

The most important thing (how to play/practice) is not obvious. There is too much text that clutters the scene, and it was designed with an adult's scanning eyes in mind. More icons, less text.

In the progress area, there is not much visual feedback on a word learning level, only a grade learning level.

Small note: The app opens to the Progess page which is on the far right tab, which is unnatural for most apps (start on the left or the middle).

As a teacher, the page looks visually the same from a distance, so it make sthe user have to read everything before clicking.

We will fix the app by simplyfying the home page for the child to what they value: their name, progress, and how to play. Major information about the progress will be simplied as well. The primary action button will be the visual hero. For high visual interest, the progress bar will be larger. The color palette will also have more visual difference to make things pop.