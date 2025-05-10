document.addEventListener('DOMContentLoaded', function() {
  // Tab navigation
  const tabButtons = document.querySelectorAll('.tab-button');
  const tabContents = document.querySelectorAll('.tab-content');
  
  tabButtons.forEach(button => {
    button.addEventListener('click', () => {
      const tabId = button.getAttribute('data-tab');
      
      // Update active button
      tabButtons.forEach(btn => btn.classList.remove('active'));
      button.classList.add('active');
      
      // Update active content
      tabContents.forEach(content => content.classList.remove('active'));
      document.getElementById(tabId).classList.add('active');
    });
  });
  
  // Initialize Feather icons
  if (typeof feather !== 'undefined') {
    feather.replace();
  }
  
  // Highlight syntax for code blocks
  const codeBlocks = document.querySelectorAll('pre code');
  highlightCodeBlocks(codeBlocks);
  
  // Add click handlers for app mockup elements
  setupMockupInteractions();
});

function highlightCodeBlocks(codeBlocks) {
  // Simple syntax highlighting
  codeBlocks.forEach(block => {
    const dartCode = block.textContent;
    
    // Very basic highlighting - in a real app would use a proper syntax highlighter
    const highlightedCode = dartCode
      .replace(/\/\/(.*)/g, '<span style="color: #98c379;">$&</span>') // Comments
      .replace(/\b(class|void|final|const|static|return|if|else|switch|case|break|continue|for|while|do|new|try|catch|throw|import|export|extends|implements|get|set|async|await|required|override|super|this|late|var|dynamic|Future|Stream|List|Map|Set|bool|int|double|String|num|true|false|null)\b/g, '<span style="color: #c678dd;">$&</span>') // Keywords
      .replace(/\b(Widget|BuildContext|StatelessWidget|StatefulWidget|State|MaterialApp|Scaffold|AppBar|Container|Row|Column|Text|Icon|Image|ListView|BoxDecoration|Padding|SizedBox|Center|InkWell|GestureDetector|Navigator|MediaQuery)\b/g, '<span style="color: #e06c75;">$&</span>') // Flutter widgets
      .replace(/(@override|@required)/g, '<span style="color: #56b6c2;">$&</span>') // Annotations
      .replace(/('.*?'|".*?")/g, '<span style="color: #98c379;">$&</span>'); // Strings
    
    block.innerHTML = highlightedCode;
  });
}

function setupMockupInteractions() {
  // Add interactivity to the app mockup
  const navIcons = document.querySelectorAll('.nav-icon');
  navIcons.forEach(icon => {
    icon.addEventListener('click', () => {
      navIcons.forEach(i => i.classList.remove('active'));
      icon.classList.add('active');
    });
  });
  
  const cameraButton = document.querySelector('.camera-button');
  if (cameraButton) {
    cameraButton.addEventListener('click', () => {
      // Show visual feedback
      cameraButton.style.transform = 'scale(0.95)';
      setTimeout(() => {
        cameraButton.style.transform = 'scale(1)';
      }, 100);
    });
  }
  
  const galleryItems = document.querySelectorAll('.gallery-item');
  galleryItems.forEach(item => {
    item.addEventListener('click', () => {
      // Show visual feedback
      item.style.transform = 'scale(0.95)';
      setTimeout(() => {
        item.style.transform = 'scale(1)';
      }, 100);
    });
  });
}
