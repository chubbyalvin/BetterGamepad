
using u8  = unsigned char;
using u16 = unsigned short;
using u32 = unsigned int;
using i32 = int;
using usize = unsigned long long;
using uptr = unsigned long long;
using Handle = void*;
using NTSTATUS = long;

static volatile long g_applyState = 0;
static volatile uptr g_lastController = 0;
static volatile u8 g_meleeActive = 0;
static volatile u8 g_aimMeleeActive = 0;
static volatile u8 g_suppressReloadCoop = 0;
static volatile u8 g_suppressRidingSkill3 = 0;
static volatile u8 g_multiRidingSkill3 = 0;
static uptr g_imageBase = 0;
static constexpr u32 PAGE_EXECUTE_READWRITE = 0x40;

#if defined(__clang__) || defined(__GNUC__)
__attribute__((used))
#endif
static const char g_betterGamepadBranding[] = "BetterGamepad Native Helper | v1.0 | by ChubbyAlvin";


static constexpr uptr RVA_RIDING_SKILL3_CALLBACK        = 0x315D510ull;
static constexpr uptr RVA_RIDING_SKILL3_FLY_GATE        = 0x315D5ABull;
static constexpr uptr RVA_ROLLCROUCH_FLY_SKILL3         = 0x315F246ull;

static constexpr uptr RVA_RELOADCOOP_D3_RELEASE_LEA     = 0x316C58Eull;
static constexpr uptr RVA_RELOADCOOP_D2_TAP_LEA         = 0x316C59Full;
static constexpr uptr RVA_RELOADCOOP_D1_HOLD_LEA        = 0x316C5AEull;
static constexpr uptr RVA_RELOADCOOP_D0_PRESS_LEA       = 0x316C5BDull;
static constexpr uptr RVA_RELOADCOOP_D3_RELEASE          = 0x315BFF0ull;
static constexpr uptr RVA_RELOADCOOP_D2_TAP              = 0x315F190ull;
static constexpr uptr RVA_RELOADCOOP_D1_HOLD             = 0x315BF30ull;
static constexpr uptr RVA_RELOADCOOP_D0_PRESS            = 0x315C880ull;

static constexpr uptr RVA_IS_RIDING                      = 0x31568B0ull;
static constexpr uptr RVA_RIDING_SKILL_SLOT              = 0x3161B10ull;
static constexpr uptr RVA_WEAPON_USE_PRESS               = 0x315ED10ull;
static constexpr uptr RVA_WEAPON_USE_RELEASE             = 0x315F850ull;
static constexpr uptr RVA_GET_PLAYER_OR_MOUNT            = 0x314DB50ull;
static constexpr uptr RVA_IS_CURRENT_WEAPON_MELEE        = 0x2CAEDD0ull;
static constexpr uptr RVA_SHOOTER_RELOAD                 = 0x2CB6480ull;
static constexpr uptr RVA_RELOAD_CONTROLLER_POST         = 0x3149DE0ull;

static constexpr uptr SHOOTER_COMPONENT_OFFSET           = 0xBE8ull;
static constexpr uptr RVA_CODE_CAVE                      = 0x082C100ull;

struct ListEntry { ListEntry* Flink; ListEntry* Blink; };
struct UnicodeString { u16 Length; u16 MaximumLength; wchar_t* Buffer; };
struct PebLdrData { u32 Length; u8 Initialized; u8 pad1[3]; void* SsHandle; ListEntry InLoadOrderModuleList; ListEntry InMemoryOrderModuleList; };
struct PebLite { u8 pad0[0x10]; void* ImageBaseAddress; PebLdrData* Ldr; };
struct LdrDataTableEntryLite {
    ListEntry InLoadOrderLinks; ListEntry InMemoryOrderLinks; ListEntry InInitializationOrderLinks;
    void* DllBase; void* EntryPoint; u32 SizeOfImage; u32 pad2; UnicodeString FullDllName; UnicodeString BaseDllName;
};

static inline PebLite* get_peb() {
#if defined(__clang__) || defined(__GNUC__)
    uptr p; __asm__ volatile ("movq %%gs:0x60, %0" : "=r"(p)); return reinterpret_cast<PebLite*>(p);
#else
    return nullptr;
#endif
}
static inline char lower_ascii(char c) { return (c >= 'A' && c <= 'Z') ? char(c + 32) : c; }
static inline wchar_t lower_wascii(wchar_t c) { return (c >= L'A' && c <= L'Z') ? wchar_t(c + 32) : c; }
static bool wname_equals_ascii(const UnicodeString& s, const char* ascii) {
    if (!s.Buffer || !ascii) return false; usize n=s.Length/sizeof(wchar_t), i=0;
    for (; i<n && ascii[i]; ++i) if (lower_wascii(s.Buffer[i]) != (wchar_t)(unsigned char)lower_ascii(ascii[i])) return false;
    return i==n && ascii[i]==0;
}
static void* find_module(const char* name) {
    PebLite* peb=get_peb(); if(!peb||!peb->Ldr) return nullptr; ListEntry* head=&peb->Ldr->InMemoryOrderModuleList;
    for(ListEntry* it=head->Flink; it&&it!=head; it=it->Flink){ auto* ent=reinterpret_cast<LdrDataTableEntryLite*>(reinterpret_cast<u8*>(it)-0x10); if(wname_equals_ascii(ent->BaseDllName,name)) return ent->DllBase; }
    return nullptr;
}
static bool ascii_equal(const char* a,const char* b){ if(!a||!b)return false; while(*a&&*b){if(*a!=*b)return false;++a;++b;} return *a==*b; }
static void* resolve_export(void* module,const char* name){
    if(!module||!name)return nullptr; u8* base=(u8*)module; if(*(u16*)base!=0x5A4D)return nullptr; i32 lfanew=*(i32*)(base+0x3C); u8* nt=base+lfanew; if(*(u32*)nt!=0x4550)return nullptr;
    u32 exportRva=*(u32*)(nt+0x88), exportSize=*(u32*)(nt+0x8C); if(!exportRva)return nullptr; u8* ed=base+exportRva;
    u32 numNames=*(u32*)(ed+24), funcsRva=*(u32*)(ed+28), namesRva=*(u32*)(ed+32), ordsRva=*(u32*)(ed+36);
    auto* funcs=(u32*)(base+funcsRva); auto* names=(u32*)(base+namesRva); auto* ords=(u16*)(base+ordsRva);
    for(u32 i=0;i<numNames;++i){const char* n=(const char*)(base+names[i]); if(!ascii_equal(n,name))continue; u32 rva=funcs[ords[i]]; if(rva>=exportRva&&rva<exportRva+exportSize)return nullptr; return base+rva;} return nullptr;
}
typedef NTSTATUS (*NtProtectVirtualMemoryFn)(Handle,void**,usize*,u32,u32*);
typedef NTSTATUS (*NtFlushInstructionCacheFn)(Handle,void*,usize);
struct NativeApi{NtProtectVirtualMemoryFn protect;NtFlushInstructionCacheFn flush;};
static bool get_native_api(NativeApi& api){void* ntdll=find_module("ntdll.dll"); if(!ntdll)return false; api.protect=(NtProtectVirtualMemoryFn)resolve_export(ntdll,"NtProtectVirtualMemory"); api.flush=(NtFlushInstructionCacheFn)resolve_export(ntdll,"NtFlushInstructionCache"); return api.protect&&api.flush;}

static bool bytes_equal(const u8* p,const u8* q,usize n){for(usize i=0;i<n;++i)if(p[i]!=q[i])return false;return true;}
static bool all_byte(const u8* p,u8 v,usize n){for(usize i=0;i<n;++i)if(p[i]!=v)return false;return true;}
static void copy_bytes(u8* d,const u8* s,usize n){for(usize i=0;i<n;++i)d[i]=s[i];}
static bool protect_rw(NativeApi& api,void* addr,usize len,u32& oldp){void* base=addr;usize size=len;return api.protect((Handle)(~uptr(0)),&base,&size,PAGE_EXECUTE_READWRITE,&oldp)>=0;}
static void restore_protect(NativeApi& api,void* addr,usize len,u32 oldp){void* base=addr;usize size=len;u32 ignored=0;api.protect((Handle)(~uptr(0)),&base,&size,oldp,&ignored);}
static bool write_protected(NativeApi& api,void* addr,const u8* src,usize len){u32 oldp=0;if(!protect_rw(api,addr,len,oldp))return false;copy_bytes((u8*)addr,src,len);api.flush((Handle)(~uptr(0)),addr,len);restore_protect(api,addr,len,oldp);return true;}

struct Writer{
    u8* b; usize cap; usize n; uptr base; bool ok;
    void e8(u8 v){if(n<cap)b[n++]=v;else ok=false;}
    void e32(u32 v){for(int i=0;i<4;++i)e8(u8(v>>(i*8)));}
    void e64(uptr v){e32((u32)v);e32((u32)(v>>32));}
};
static void emit_movabs_rax(Writer& w, uptr value){w.e8(0x48);w.e8(0xB8);w.e64(value);}

static usize build_conditional_callback_stub(u8* out,usize cap,uptr stubVA,volatile u8* suppressFlag,uptr originalVA){
    Writer w{out,cap,0,stubVA,true};
    emit_movabs_rax(w,(uptr)&g_lastController); w.e8(0x48);w.e8(0x89);w.e8(0x08);
    emit_movabs_rax(w,(uptr)suppressFlag); w.e8(0x80);w.e8(0x38);w.e8(0x00);
    w.e8(0x75);w.e8(0x0C);
    emit_movabs_rax(w,originalVA); w.e8(0xFF);w.e8(0xE0);
    w.e8(0xC3);
    return w.ok?w.n:0;
}

static usize build_riding_entry_stub(u8* out,usize cap,uptr stubVA,uptr resumeVA){
    Writer w{out,cap,0,stubVA,true};
    emit_movabs_rax(w,(uptr)&g_lastController); w.e8(0x48);w.e8(0x89);w.e8(0x08);
    emit_movabs_rax(w,(uptr)&g_suppressRidingSkill3); w.e8(0x80);w.e8(0x38);w.e8(0x00);
    w.e8(0x75);w.e8(0x12);
    w.e8(0x40);w.e8(0x57);
    w.e8(0x48);w.e8(0x83);w.e8(0xEC);w.e8(0x20);
    emit_movabs_rax(w,resumeVA); w.e8(0xFF);w.e8(0xE0);
    w.e8(0xC3);
    return w.ok?w.n:0;
}

static bool patch_lea_to(NativeApi& api, uptr imageBase, uptr leaRva, uptr targetVA) {
    u8 patch[7]={0x48,0x8D,0x05,0,0,0,0};
    long long diff=(long long)targetVA-(long long)(imageBase+leaRva+7);
    if(diff<-2147483648ll||diff>2147483647ll) return false;
    i32 rel=(i32)diff; patch[3]=u8(rel);patch[4]=u8(rel>>8);patch[5]=u8(rel>>16);patch[6]=u8(rel>>24);
    return write_protected(api,(void*)(imageBase+leaRva),patch,7);
}
static bool patch_entry_jump6(NativeApi& api, uptr fromVA, uptr toVA){
    long long diff=(long long)toVA-(long long)(fromVA+5);
    if(diff<-2147483648ll||diff>2147483647ll) return false;
    i32 rel=(i32)diff;
    u8 p[6]={0xE9,u8(rel),u8(rel>>8),u8(rel>>16),u8(rel>>24),0x90};
    return write_protected(api,(void*)fromVA,p,6);
}

static bool apply_all(){
    PebLite* peb=get_peb(); if(!peb||!peb->ImageBaseAddress){g_applyState=-1;return false;} uptr base=(uptr)peb->ImageBaseAddress;
    NativeApi api{nullptr,nullptr}; if(!get_native_api(api)){g_applyState=-2;return false;}

    u8* rideEntry=(u8*)(base+RVA_RIDING_SKILL3_CALLBACK);
    u8* rideFly=(u8*)(base+RVA_RIDING_SKILL3_FLY_GATE);
    u8* rollFly=(u8*)(base+RVA_ROLLCROUCH_FLY_SKILL3);
    u8* d3=(u8*)(base+RVA_RELOADCOOP_D3_RELEASE_LEA); u8* d2=(u8*)(base+RVA_RELOADCOOP_D2_TAP_LEA);
    u8* d1=(u8*)(base+RVA_RELOADCOOP_D1_HOLD_LEA); u8* d0=(u8*)(base+RVA_RELOADCOOP_D0_PRESS_LEA);
    u8* cave=(u8*)(base+RVA_CODE_CAVE);

    const u8 expRideEntry[6]={0x40,0x57,0x48,0x83,0xEC,0x20};
    const u8 expRideFly[2]={0x75,0x2B};
    const u8 expRollFly[2]={0x74,0x2B};
    const u8 expD3[7]={0x48,0x8D,0x05,0x5B,0xFA,0xFE,0xFF};
    const u8 expD2[7]={0x48,0x8D,0x05,0xEA,0x2B,0xFF,0xFF};
    const u8 expD1[7]={0x48,0x8D,0x05,0x7B,0xF9,0xFE,0xFF};
    const u8 expD0[7]={0x48,0x8D,0x05,0xBC,0x02,0xFF,0xFF};

    if(!bytes_equal(rideEntry,expRideEntry,6)||!bytes_equal(rideFly,expRideFly,2)||!bytes_equal(rollFly,expRollFly,2)||
       !bytes_equal(d3,expD3,7)||!bytes_equal(d2,expD2,7)||!bytes_equal(d1,expD1,7)||!bytes_equal(d0,expD0,7)||
       !all_byte(cave,0xCC,512)){
        g_applyState=-3;return false;
    }

    g_imageBase=base; g_lastController=0; g_meleeActive=0; g_aimMeleeActive=0;
    g_suppressReloadCoop=0; g_suppressRidingSkill3=0; g_multiRidingSkill3=0;

    u8 stubs[512]; usize used=0;
    auto append=[&](usize n){used+=n;};

    uptr d0StubVA=base+RVA_CODE_CAVE+used;
    usize n=build_conditional_callback_stub(stubs+used,sizeof(stubs)-used,d0StubVA,&g_suppressReloadCoop,base+RVA_RELOADCOOP_D0_PRESS); if(!n){g_applyState=-4;return false;} append(n);
    uptr d1StubVA=base+RVA_CODE_CAVE+used;
    n=build_conditional_callback_stub(stubs+used,sizeof(stubs)-used,d1StubVA,&g_suppressReloadCoop,base+RVA_RELOADCOOP_D1_HOLD); if(!n){g_applyState=-5;return false;} append(n);
    uptr d2StubVA=base+RVA_CODE_CAVE+used;
    n=build_conditional_callback_stub(stubs+used,sizeof(stubs)-used,d2StubVA,&g_suppressReloadCoop,base+RVA_RELOADCOOP_D2_TAP); if(!n){g_applyState=-6;return false;} append(n);
    uptr d3StubVA=base+RVA_CODE_CAVE+used;
    n=build_conditional_callback_stub(stubs+used,sizeof(stubs)-used,d3StubVA,&g_suppressReloadCoop,base+RVA_RELOADCOOP_D3_RELEASE); if(!n){g_applyState=-7;return false;} append(n);
    uptr rideStubVA=base+RVA_CODE_CAVE+used;
    n=build_riding_entry_stub(stubs+used,sizeof(stubs)-used,rideStubVA,base+RVA_RIDING_SKILL3_CALLBACK+6); if(!n){g_applyState=-8;return false;} append(n);

    if(!write_protected(api,cave,stubs,used)){g_applyState=-9;return false;}
    if(!patch_lea_to(api,base,RVA_RELOADCOOP_D0_PRESS_LEA,d0StubVA)){g_applyState=-10;return false;}
    if(!patch_lea_to(api,base,RVA_RELOADCOOP_D1_HOLD_LEA,d1StubVA)){g_applyState=-11;return false;}
    if(!patch_lea_to(api,base,RVA_RELOADCOOP_D2_TAP_LEA,d2StubVA)){g_applyState=-12;return false;}
    if(!patch_lea_to(api,base,RVA_RELOADCOOP_D3_RELEASE_LEA,d3StubVA)){g_applyState=-13;return false;}
    if(!patch_entry_jump6(api,base+RVA_RIDING_SKILL3_CALLBACK,rideStubVA)){g_applyState=-14;return false;}

    const u8 patchRideFly[2]={0x90,0x90};
    const u8 patchRollFly[2]={0xEB,0x2B};
    if(!write_protected(api,rideFly,patchRideFly,2)){g_applyState=-15;return false;}
    if(!write_protected(api,rollFly,patchRollFly,2)){g_applyState=-16;return false;}

    g_applyState=1; return true;
}

using ControllerFn = void (*)(void*);
using RidingFn = bool (*)(void*);
using SkillFn = bool (*)(void*, int);
using MeleeFn = bool (*)(void*);

static void* controller_now(){ return (void*)g_lastController; }
static bool is_riding(void* controller){
    if(!controller || !g_imageBase) return false;
    return ((RidingFn)(g_imageBase+RVA_IS_RIDING))(controller);
}
static void* shooter_component_proven(void* controller){
    if(!controller || !g_imageBase) return nullptr;
    void* player=((void*(*)(void*))(g_imageBase+RVA_GET_PLAYER_OR_MOUNT))(controller);
    if(!player) return nullptr;
    return *(void**)((u8*)player + SHOOTER_COMPONENT_OFFSET);
}
static bool current_weapon_is_melee(void* controller){
    void* shooter=shooter_component_proven(controller);
    if(!shooter || !g_imageBase) return false;
    return ((MeleeFn)(g_imageBase+RVA_IS_CURRENT_WEAPON_MELEE))(shooter);
}
static void stock_reload_semantic(void* controller){
    if(!controller || !g_imageBase) return;
    ((ControllerFn)(g_imageBase+RVA_RELOADCOOP_D2_TAP))(controller);
}

extern "C" __declspec(dllexport) int bettergamepad_apply(void*){
    if(g_applyState==0) apply_all();
    return 0;
}
extern "C" __declspec(dllexport) int bettergamepad_suppress_reloadcoop_on(void*){g_suppressReloadCoop=1;return 0;}
extern "C" __declspec(dllexport) int bettergamepad_suppress_reloadcoop_off(void*){g_suppressReloadCoop=0;return 0;}
extern "C" __declspec(dllexport) int bettergamepad_suppress_ridingskill3_on(void*){
    // Vanilla Riding Skill 3 remains suppressed while BetterGamepad is active.
    // This call also grants the multi-action key ownership of deliberate Skill 3.
    g_suppressRidingSkill3=1;
    g_multiRidingSkill3=1;
    return 0;
}
extern "C" __declspec(dllexport) int bettergamepad_multi_ridingskill3_off(void*){
    // Disable only Skill 3 on the multi-action key. Keep vanilla suppression enabled
    // so Roll/Crouch/Descend cannot accidentally trigger Riding Skill 3.
    g_multiRidingSkill3=0;
    return 0;
}

extern "C" __declspec(dllexport) int bettergamepad_tap_context(void*){
    if(g_applyState!=1 || g_imageBase==0) return 0;
    void* controller=controller_now(); if(!controller) return 0;
    if(is_riding(controller)){
        if(g_multiRidingSkill3){
            bool fired=((SkillFn)(g_imageBase+RVA_RIDING_SKILL_SLOT))(controller,2);
            if(!fired) stock_reload_semantic(controller);
        }else{
            stock_reload_semantic(controller);
        }
        return 0;
    }
    if(current_weapon_is_melee(controller)){
        g_meleeActive=1;
        ((ControllerFn)(g_imageBase+RVA_WEAPON_USE_PRESS))(controller);
    }else{
        stock_reload_semantic(controller);
    }
    return 0;
}

extern "C" __declspec(dllexport) int bettergamepad_tap_partner_priority(void*){
    if(g_applyState!=1 || g_imageBase==0) return 0;
    void* controller=controller_now(); if(!controller) return 0;
    if(is_riding(controller)){
        if(g_multiRidingSkill3){
            bool fired=((SkillFn)(g_imageBase+RVA_RIDING_SKILL_SLOT))(controller,2);
            if(!fired) stock_reload_semantic(controller);
        }else{
            stock_reload_semantic(controller);
        }
    }else{
        ((ControllerFn)(g_imageBase+RVA_RELOADCOOP_D1_HOLD))(controller);
    }
    return 0;
}

extern "C" __declspec(dllexport) int bettergamepad_partner_skill(void*){
    if(g_applyState!=1 || g_imageBase==0) return 0;
    void* controller=controller_now(); if(!controller) return 0;
    ((ControllerFn)(g_imageBase+RVA_RELOADCOOP_D1_HOLD))(controller);
    return 0;
}

extern "C" __declspec(dllexport) int bettergamepad_riding_skill3(void*){
    if(g_applyState!=1 || g_imageBase==0) return 0;
    void* controller=controller_now(); if(!controller || !is_riding(controller)) return 0;
    ((SkillFn)(g_imageBase+RVA_RIDING_SKILL_SLOT))(controller,2);
    return 0;
}

extern "C" __declspec(dllexport) int bettergamepad_aim_multi_press(void*){
    if(g_applyState!=1 || g_imageBase==0 || g_aimMeleeActive) return 0;
    void* controller=controller_now(); if(!controller) return 0;
    if(is_riding(controller)) return 0;
    if(current_weapon_is_melee(controller)){
        g_aimMeleeActive=1;
        ((ControllerFn)(g_imageBase+RVA_WEAPON_USE_PRESS))(controller);
    }
    return 0;
}
extern "C" __declspec(dllexport) int bettergamepad_aim_multi_release(void*){
    if(g_applyState!=1 || g_imageBase==0) return 0;
    void* controller=controller_now(); if(!controller) return 0;
    if(g_aimMeleeActive){
        g_aimMeleeActive=0;
        ((ControllerFn)(g_imageBase+RVA_WEAPON_USE_RELEASE))(controller);
    }else{
        stock_reload_semantic(controller);
    }
    return 0;
}

extern "C" __declspec(dllexport) int bettergamepad_finish_melee(void*){
    if(g_applyState!=1 || g_imageBase==0 || g_meleeActive==0) return 0;
    void* controller=controller_now(); g_meleeActive=0;
    if(controller) ((ControllerFn)(g_imageBase+RVA_WEAPON_USE_RELEASE))(controller);
    return 0;
}
