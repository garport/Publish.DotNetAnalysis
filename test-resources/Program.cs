using System;

namespace CodeAnalysisExample
{
    class Program
    {
        static void Main(string[] args)
        {
            // Line 10: Issue will be here
            var resource = new System.IO.StreamReader("example.txt");

            // Do something with the resource

            // Forgot to dispose the resource, which will cause a CA2000 warning
        }
    }
}
