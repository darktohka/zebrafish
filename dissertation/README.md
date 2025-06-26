# Project Raccoon - Management of a Platform to Streamline Contract Creation and Property Sales Through the Web

This repository contains the LaTeX source code for the dissertation titled "Project Raccoon - Management of a Platform to Streamline Contract Creation and Property Sales Through the Web".

## Abstract

The abstract introduces the core problem the dissertation addresses: the complexity and high cost associated with drafting legally sound property sale contracts for individuals and businesses. It proposes the development of an online platform, Project Raccoon, to simplify and automate this process. The project has two main goals: first, to design and build the foundational software architecture for a platform that allows administrators to create document templates and end-users to generate filled-out PDF contracts from them. Second, to document and measure the performance of different deployment strategies for this platform in real-world scenarios. The abstract positions the project as a more user-friendly and efficient alternative to existing, often convoluted, government-backed solutions.

## Chapters

### Chapter 1: Introduction

This chapter sets the stage for the dissertation by providing a detailed background on the challenges in the real estate sector that motivated the project. It elaborates on the cumbersome nature of creating property sale agreements, which often requires deep legal knowledge or expensive professional assistance. The introduction establishes the primary objective of the project: to conceptualize and develop a web-based platform that empowers users to create customized, legally compliant contracts with ease. It outlines the vision for a system that reduces the time, effort, and cost involved in property transactions, thereby making the process more accessible.

### Chapter 2: Software Utilized

This chapter provides a high-level overview of the technology stack chosen for the project. It discusses the various types of software components that were integrated to build the platform. This includes the frontend technologies responsible for creating a dynamic and responsive user interface, the backend systems that handle business logic and data processing, and the database solutions for persistent data storage. The chapter also touches upon the selection of specific libraries for core functionalities like PDF generation and the use of containerization technologies to ensure consistent deployment and scalability.

### Chapter 3: Specification

This chapter presents a detailed Software Requirements Specification (SRS), defining the precise capabilities of the platform. It breaks down the requirements into two main areas: the administrative interface and the end-user interface. For administrators, the specification outlines functionalities for creating, managing, and customizing contract templates. For end-users, it details the process of selecting a template, filling in the required information through a user-friendly form, and generating the final PDF document. The chapter also covers non-functional requirements such as performance benchmarks, security standards, and usability goals.

### Chapter 4: Architecture

This chapter delves into the architectural design of the platform. It describes the system's structure, detailing the separation between the client-side application (the user interface) and the server-side services. The chapter explains the flow of data and the design of the API that connects the frontend and backend. It also explores and compares two potential deployment models: a traditional container-based architecture and a modern serverless architecture. The discussion weighs the pros and cons of each approach in the context of the platform's specific needs, such as scalability, cost-effectiveness, and ease of maintenance.

### Chapter 5: Interface

This chapter focuses on the user-facing aspects of the platform, providing a comprehensive walkthrough of the user interface (UI) and user experience (UX). It presents the visual design and layout of the application through mockups and screenshots. The chapter illustrates the step-by-step journey for both administrators and end-users. It shows how an administrator would navigate their dashboard to construct a new contract template, defining various input fields and arranging the layout. It then demonstrates how a typical end-user would interact with the platform to select a template and generate a personalized contract.

### Chapter 6: Measurements and Evaluation

This chapter is dedicated to the quantitative evaluation of the architectural decisions made during the project's design phase. It presents a series of performance measurements and benchmarks that were conducted to validate the chosen technology stack and deployment strategy. The analysis focuses on key performance indicators, such as the time taken to generate PDF documents and the response time of the server under different loads. The results are used to rationalize the selection of a serverless approach over a container-based one, providing empirical evidence to support the final architectural design.

### Chapter 7: Conclusion

The final chapter provides a comprehensive summary of the entire dissertation, reiterating the project's goals, methods, and results. It concludes that the project successfully laid the groundwork for a viable platform to streamline contract creation. The chapter also includes a discussion on the limitations of the current implementation and proposes several avenues for future work. These potential enhancements include expanding the variety of contract templates, integrating third-party services for identity verification, and further refining the user interface based on user feedback.

## Build

To build the PDF of the dissertation, you can use the provided build script:

```bash
./build.sh
```
This will generate a file named `output.pdf`.