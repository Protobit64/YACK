

        
        Add-Type -TypeDefinition @"
        using System;
        using System.Diagnostics;
        using System.Runtime.InteropServices;
        using System.Security.Principal;
        
        [StructLayout(LayoutKind.Sequential, Pack = 1)]
        public struct SYSTEM_HANDLE_INFORMATION
        {
            public UInt32 ProcessID;
            public Byte ObjectTypeNumber;
            public Byte Flags;
            public UInt16 HandleValue;
            public IntPtr Object_Pointer;
            public UInt32 GrantedAccess;
        }
        
        public static class GetHandles
        {
            [DllImport("ntdll.dll")]
            public static extern int NtQuerySystemInformation(
                int SystemInformationClass,
                IntPtr SystemInformation,
                int SystemInformationLength,
                ref int ReturnLength);
        }
"@
    