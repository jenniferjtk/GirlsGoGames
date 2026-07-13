Hours Worked: 10
I began with ensuring that my connection with our team’s supabase instance was working as expected. I had to troubleshoot some issues that were resolved when the team realized the URL was outdated
Began working on the backend proxy by creating the backend folder and the necessary server files. Used ai to assist in the creation of a thin Express server that uses node.js, as my team decided this was the best solution for the backend proxy
Added a separate .env file for the backend to keep the supabase and api credentials separate in case .env was accidentally committed 
Ai Suggested I implement a /health endpoint to verify the proxy was working before beginning to implement AI functionality
After verifying the server was functional with the health endpoint, implemented the /generate-story endpoint that accepts a prompt from the flutter front end and returns a generated story
AI suggested that I test the server manually with powershell before connecting it to flutter to test each segment and make debugging easier
Encountered an error because the mini model did not accept a temperature parameter, which was added in the backend code. This was removed and the request worked as expected
At this point, I wanted to ensure that there was no possibility for excessive API calls to be made. I added additional logging to the terminal for the backend server so there would be logging for every API call made. 
After this, I created a new AI story builder screen in flutter that allows the usr to enter a text field and a generate story button
There was an issue with the database with an ambiguous supabase relationship that I troubleshot and fixed 
I tested extensively the AI workflow by running the app and generating dolche based stories from within the application

